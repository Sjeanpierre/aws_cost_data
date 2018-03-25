for i in $(aws ec2 describe-regions | jq -r '.Regions[].RegionName') ; do
  aws rds describe-db-instances --output text --region $i --query "DBInstances[*].{Name:DBInstanceIdentifier,Size:DBInstanceClass,StorageType:StorageType,Iops:Iops,VolumeEncrypted:StorageEncrypted,DBType:Engine,Version:EngineVersion,MultiAZ:MultiAZ,AZ:AvailabilityZone}"
done  