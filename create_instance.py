import sys
import boto3

ec2_resource = boto3.resource('ec2')
ec2_client = boto3.client('ec2')
my_ip=print(sys.argv[1])

# create aws instance for application if not exists
def create_instance():
  subnet_id = ec2_client.describe_subnets(Filters=[{'Name': 'cidr-block', 'Values': ['10.1.1.0/25']}])['Subnets'][0]['SubnetId']
  vpc_id = ec2_client.describe_vpcs(Filters=[{'Name':'cidr', 'Values':['10.1.0.0/16']}])['Vpcs'][0]['VpcId']
  sec = ec2_client.describe_security_groups(Filters=[{'Name':'vpc-id', 'Values':[vpc_id]}])['SecurityGroups'][0]['GroupId']

  instance = ec2_resource.create_instances(
      ImageId='ami-0d5d9d301c853a04a',
      InstanceType='t2.small',
      KeyName='idan_keypair',
      MaxCount=1,
      MinCount=1,
      Monitoring={
          'Enabled': True
      },
      Placement={
          'AvailabilityZone': 'us-east-2b',
      },
      SecurityGroupIds=[
          sec,
      ],
      SubnetId=subnet_id,
      ClientToken='application-server',
      PrivateIpAddress=my_ip,
      CreditSpecification={
          'CpuCredits': 'standard'
      },
  )
  
  
create_instance(