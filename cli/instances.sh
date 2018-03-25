for i in $(aws ec2 describe-regions | jq -r '.Regions[].RegionName') ; do
   aws ec2 describe-instances --output text --region $i --query 'Reservations[*].Instances[*].[InstanceId, InstanceType, State.Name, Placement.AvailabilityZone, [Tags[?Key==`Name`].Value] [0][0], [Tags[?Key==`environment`].Value] [0][0] ]';
done

#aws ec2 describe-instances --output text --query 'Reservations[*].Instances[*].[InstanceId, InstanceType, State.Name, Placement.AvailabilityZone, [Tags[?Key==`Name`].Value] [0][0], [Tags[?Key==`environment`].Value] [0][0] ]'