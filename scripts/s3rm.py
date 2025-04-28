import boto3
from botocore.exceptions import ClientError
import os
import sys


def delete_all_objects_and_versions(bucket_name, prefix):
    """
    Recursively delete all objects and their versions in the specified bucket prefix
    """
    # Create S3 client
    # You may need to adjust the endpoint_url to match your TrueNAS configuration
    s3 = boto3.client("s3")
    # Uncomment or set these parameters as needed for your TrueNAS setup
    # endpoint_url='http://your-truenas-ip:port',
    # aws_access_key_id='your-access-key',
    # aws_secret_access_key='your-secret-key',

    print(f"Starting deletion of all objects in {bucket_name}/{prefix}")

    try:
        # Check if versioning is enabled
        versioning = s3.get_bucket_versioning(Bucket=bucket_name)
        versioning_enabled = versioning.get("Status") == "Enabled"

        if versioning_enabled:
            print("Bucket has versioning enabled, deleting all versions...")
            # List and delete all object versions
            paginator = s3.get_paginator("list_object_versions")
            for page in paginator.paginate(Bucket=bucket_name, Prefix=prefix):
                # Delete versions
                if "Versions" in page:
                    delete_keys = [
                        {"Key": obj["Key"], "VersionId": obj["VersionId"]}
                        for obj in page["Versions"]
                        if obj["Key"].startswith(prefix)
                    ]
                    if delete_keys:
                        s3.delete_objects(
                            Bucket=bucket_name, Delete={"Objects": delete_keys}
                        )
                        print(f"Deleted {len(delete_keys)} object versions")

                # Delete delete markers
                if "DeleteMarkers" in page:
                    delete_markers = [
                        {"Key": obj["Key"], "VersionId": obj["VersionId"]}
                        for obj in page["DeleteMarkers"]
                        if obj["Key"].startswith(prefix)
                    ]
                    if delete_markers:
                        s3.delete_objects(
                            Bucket=bucket_name, Delete={"Objects": delete_markers}
                        )
                        print(f"Deleted {len(delete_markers)} delete markers")
        else:
            print(
                "Bucket does not have versioning enabled, deleting current objects..."
            )
            # List and delete all current objects
            paginator = s3.get_paginator("list_objects_v2")
            for page in paginator.paginate(Bucket=bucket_name, Prefix=prefix):
                if "Contents" in page:
                    delete_keys = [{"Key": obj["Key"]} for obj in page["Contents"]]
                    if delete_keys:
                        s3.delete_objects(
                            Bucket=bucket_name, Delete={"Objects": delete_keys}
                        )
                        print(f"Deleted {len(delete_keys)} objects")

        print(f"Successfully deleted all objects in {bucket_name}/{prefix}")
        return True

    except ClientError as e:
        print(f"Error: {e}")
        return False


if __name__ == "__main__":
    bucket_name = "mazenet-backup-truenas"
    prefix = "truenas-home/blockchains/"

    success = delete_all_objects_and_versions(bucket_name, prefix)
    if success:
        print("Deletion completed successfully.")
    else:
        print("Deletion failed.")
