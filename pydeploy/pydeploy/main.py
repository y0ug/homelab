import argparse
import logging
import os
import time
import json
import paramiko
from paramiko.ssh_exception import NoValidConnectionsError

from typing import Dict
from urllib.parse import urlparse

import yaml
from dotenv import load_dotenv
from proxmoxer import ProxmoxAPI, ResourceException
from pydantic import BaseModel, Field


# Define the Pydantic model for each VM
class VM(BaseModel):
    vmid: int = Field(None)
    ram: int = Field(None)
    vcpus: int = Field(None)
    networks: Dict[str, str] = Field(None)
    disks: Dict[str, str] = Field(None)
    tags: str = Field(None)
    desc: str = Field(None)
    target_node: str = Field(None)
    sockets: int = Field(None)
    cores: int = Field(None)
    balloon: int = Field(None)
    cpu: str = Field(None)
    agent: bool = Field(None)
    onboot: bool = Field(None)
    qemu_os: str = Field(None)
    hotplug: str = Field(None)
    bios: str = Field(None)
    boot: str = Field(None)
    tablet: bool = Field(None)
    numa: bool = Field(None)
    scsihw: str = Field(None)


# Define the container model for the VMs
class VMsConfig(BaseModel):
    vms: Dict[str, VM]
    defaults: VM

    # Helper method to load from a yaml file
    @classmethod
    def from_yaml(cls, filepath: str):
        with open(filepath, "r") as f:
            data = yaml.safe_load(f)

        return cls.parse_obj(data)


def merge_dicts(dict1, dict2):
    """Merge two dictionaries recursively."""
    for key, value in dict2.items():
        if key in dict1:
            # If the value is a dictionary, recurse
            if isinstance(dict1[key], dict) and isinstance(value, dict):
                merge_dicts(dict1[key], value)
            else:
                # If not a dictionary, overwrite the value
                dict1[key] = value
        else:
            dict1[key] = value
    return dict1


def check_ssh_connection(ip_address: str, timeout: int = 120) -> bool:
    """Check SSH connection using Paramiko and SSH-agent"""
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    # Attempt SSH connection using SSH-agent
    try:
        start_time = time.time()
        while time.time() - start_time < timeout:
            try:
                logging.info(f"Trying to connect to {ip_address} via SSH")
                ssh.connect(
                    hostname=ip_address,
                    username="deploy",  # replace with appropriate username
                    allow_agent=True,
                    look_for_keys=True,
                    timeout=5,
                )
                stdin, stdout, stderr = ssh.exec_command("uname -a")
                uname_output = stdout.read().decode().strip()  # Get command output
                logging.info(f"{ip_address}: {uname_output}")
                return True  # Connection successful
            except (NoValidConnectionsError, TimeoutError):
                logging.info(f"SSH connection not ready for {ip_address}, retrying...")
                time.sleep(5)  # Wait before retrying
        return False  # Connection failed after timeout
    except Exception as e:
        logging.error(f"Error during SSH connection to {ip_address}: {e}")
        return False
    finally:
        ssh.close()


def setup_logging(verbosity):
    """Set up logging configuration."""
    levels = {0: logging.WARNING, 1: logging.INFO, 2: logging.DEBUG}
    level = levels.get(verbosity, logging.DEBUG)
    logging.basicConfig(level=level, format="%(asctime)s - %(levelname)s - %(message)s")


def parse_args():
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(description="Manage VMs with Proxmox")
    parser.add_argument(
        "-v",
        "--verbose",
        action="count",
        default=0,
        help="Increase verbosity (-v, -vv, -vvv)",
    )
    parser.add_argument(
        "-f", "--file", required=True, help="Path to YAML file that defines the VMs"
    )
    parser.add_argument(
        "action",
        choices=["apply", "destroy", "start", "stop", "wait"],
        help="Action to perform (apply or destroy VMs)",
    )
    return parser.parse_args()


def apply_vms(prox: ProxmoxAPI, configs: Dict[str, VM]):
    """Apply the VMs configuration to Proxmox."""
    for vm_name, config in configs.items():
        logging.info(f"Creating VM: {vm_name}")

        # Build parameters for VM creation
        params = {
            "name": vm_name,
            "vmid": config.vmid,
            "tags": config.tags,
            "sockets": config.sockets,
            "cpu": config.cpu,
            "cores": config.cores,
            "vcpus": config.vcpus,
            "numa": 1 if config.numa else 0,
            "memory": config.ram,
            "balloon": config.balloon,
            "scsihw": config.scsihw,
            "hotplug": config.hotplug,
            "boot": config.boot,
            "onboot": 1 if config.onboot else 0,
            "agent": 1 if config.agent else 0,
            "tablet": 1 if config.tablet else 0,
            "bios": config.bios,
            "ostype": config.qemu_os,
        }

        # Add networks and disks
        params.update(config.networks)
        params.update(config.disks)

        prox.nodes(config.target_node).qemu.create(**params)
        logging.info(f"VM {vm_name} creation triggered successfully.")


def destroy_vms(prox: ProxmoxAPI, configs: Dict[str, VM]):
    """Destroy the VMs defined in the configuration."""
    for vm_name, config in configs.items():
        logging.info(f"Destroying VM: {vm_name}")
        try:
            node = config.target_node
            logging.info(f'Stopping VM "{config.vmid}" on node "{node}"...')

            prox.nodes(node).qemu(config.vmid).status.stop.post(node=node)

            status = "running"
            for _ in range(10):
                status = (
                    prox.nodes(node).qemu(config.vmid).status.current.get()["status"]
                )
                if status == "stopped":
                    break
                time.sleep(1)

            prox.nodes(node).qemu(config.vmid).delete(node=node)
            logging.info(f"VM {vm_name} destroyed successfully.")
        except Exception as e:
            logging.error(f"Failed to destroy VM {vm_name}: {e}")


def start_vms(prox: ProxmoxAPI, configs: Dict[str, VM]):
    """Destroy the VMs defined in the configuration."""
    for vm_name, config in configs.items():
        logging.info(f"Starting VM: {vm_name}")
        try:
            node = config.target_node
            prox.nodes(node).qemu(config.vmid).status.start.post(node=node)
            for _ in range(10):
                logging.info(f"Waiting VM: {vm_name} to start")
                status = (
                    prox.nodes(node).qemu(config.vmid).status.current.get()["status"]
                )
                if status == "running":
                    break
                time.sleep(1)
        except Exception as e:
            logging.error(f"Failed to start VM {vm_name}: {e}")


def stop_vms(prox: ProxmoxAPI, configs: Dict[str, VM]):
    """Destroy the VMs defined in the configuration."""
    for vm_name, config in configs.items():
        logging.info(f"Starting VM: {vm_name}")
        try:
            node = config.target_node
            prox.nodes(node).qemu(config.vmid).status.stop.post(node=node)
            for _ in range(10):
                logging.info(f"Waiting VM: {vm_name} to stop")
                status = (
                    prox.nodes(node).qemu(config.vmid).status.current.get()["status"]
                )
                if status == "stopped":
                    break
                time.sleep(1)
        except Exception as e:
            logging.exception(f"Failed to stop VM {vm_name}: {e}")


def wait_vms(prox: ProxmoxAPI, configs: Dict[str, VM]):
    """Wait for VM to have an IP"""
    targets = configs.copy()
    for i in range(0, 10):
        tmp = targets.copy()
        for vm_name, config in tmp.items():
            logging.info(f"Waiting for VM: {vm_name}")
            try:
                node = config.target_node
                data = (
                    prox.nodes(node)
                    .qemu(config.vmid)
                    .agent("network-get-interfaces")
                    .get()
                )
                interfaces = data.get("result")
                # logging.info(json.dumps(interfaces, indent=4))
                if interfaces:
                    ipv4_addresses = []
                    for interface in interfaces:
                        if interface["name"] != "lo":  # Exclude 'lo' interface
                            for ip in interface["ip-addresses"]:
                                if ip["ip-address-type"] == "ipv4":
                                    ipv4_addresses.append(ip["ip-address"])
                    if ipv4_addresses:
                        ip_address = ipv4_addresses[0]
                        logging.info(f"VM {vm_name} has IP: {ip_address}")
                        if check_ssh_connection(ip_address):
                            logging.info(
                                f"SSH connection successful for {vm_name} ({ip_address})"
                            )
                            del targets[vm_name]
                        else:
                            logging.error(
                                f"SSH connection failed for {vm_name} ({ip_address})"
                            )
                    logging.warning(ipv4_addresses[0])
            except ResourceException as e:
                if e.content == "QEMU guest agent is not running":
                    logging.info(f"{vm_name}: no qemu")
                    continue
            except Exception as e:
                logging.error(f"Failed to wait VM {vm_name}: {e}")
        time.sleep(15)


def main():
    args = parse_args()
    setup_logging(args.verbose)

    load_dotenv()
    parsed_url = urlparse(os.getenv("PM_API_URL"))
    user, token_name = os.getenv("PM_API_TOKEN_ID").split("!")
    prox = ProxmoxAPI(
        parsed_url.hostname,
        port=parsed_url.port,
        user=user,
        token_name=token_name,
        token_value=os.getenv("PM_API_TOKEN_SECRET"),
        verify_ssl=bool(os.getenv("PM_TLS_INSECURE")),
    )

    # Load VMs configuration from the YAML file
    vms_config = VMsConfig.from_yaml(args.file)

    configs: Dict[str, VM] = {}
    for vm_name, vm in vms_config.vms.items():
        config_ = merge_dicts(
            vms_config.defaults.dict(exclude_unset=True),
            vm.dict(exclude_unset=True),
        )
        config = VM.model_validate(config_)
        configs[vm_name] = config

    # Apply or destroy VMs based on the action
    if args.action == "apply":
        apply_vms(prox, configs)
    elif args.action == "destroy":
        destroy_vms(prox, configs)
    elif args.action == "start":
        start_vms(prox, configs)
    elif args.action == "stop":
        stop_vms(prox, configs)
    elif args.action == "wait":
        wait_vms(prox, configs)


if __name__ == "__main__":
    main()
