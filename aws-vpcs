# This automation creates external+internal VPC's and sets the connectivity between them

import boto3
ec2_resource = boto3.resource('ec2')
ec2_client = boto3.client('ec2')
eks_client = boto3.client('eks')


def create_external_vpc():
  # create VPC in the range of 10.0.0.0/16
  vpc = ec2_resource.create_vpc(CidrBlock='10.0.0.0/16')
  
  # create an Internet GW
  internetgateway = ec2_resource.create_internet_gateway()
  vpc.attach_internet_gateway(InternetGatewayId=internetgateway.id)
  
  # allow access to the internet
  routetable = vpc.create_route_table()
  route = routetable.create_route(DestinationCidrBlock='0.0.0.0/0', GatewayId=internetgateway.id)
  
  # create 4 subnets
  for i in range(1,5):
    cidr=(f'10.0.{i}.0/25')
    subnet = ec2_resource.create_subnet(CidrBlock=cidr, VpcId=vpc.id)
    routetable.associate_with_subnet(SubnetId=subnet.id)


def create_internal_vpc():
  # create VPC in the range of 10.1.0.0/16
  vpc = ec2_resource.create_vpc(CidrBlock='10.1.0.0/16')
  
  # for the k8s to be created later
  client.modify_vpc_attribute(
    EnableDnsHostnames={
        'Value': True
    },
    EnableDnsSupport={
        'Value': True
    },
    VpcId=vpc.id
  )
  
  # create 3 subnets
  routetable = vpc.create_route_table()
  for i in range(1,4):
    cidr=(f'10.1.{i}.0/25')
    subnet = ec2_resource.create_subnet(CidrBlock=cidr, VpcId=vpc.id)
    routetable.associate_with_subnet(SubnetId=subnet.id)
    
  # create another subnet in a differenet AZ for eks
  cidr=(f'10.1.6.0/25')
  subnet = ec2_resource.create_subnet(CidrBlock=cidr, VpcId=vpc.id, AvailabilityZone='us-east-2a')
  routetable.associate_with_subnet(SubnetId=subnet.id)
  
def establish_conectivity():
  # get VPCs IDs
  ext_id = ec2_client.describe_vpcs(Filters=[{'Name':'cidr', 'Values':['10.0.0.0/16']}])['Vpcs'][0]['VpcId']
  int_id = ec2_client.describe_vpcs(Filters=[{'Name':'cidr', 'Values':['10.1.0.0/16']}])['Vpcs'][0]['VpcId']

  # create peering network
  vpc_peering_connection = ec2_resource.create_vpc_peering_connection(
    PeerVpcId=int_id,
    VpcId=ext_id,
  )
  
  int_route_table = ec2_client.describe_route_tables(Filters=[{'Name': 'vpc-id', 'Values': [int_id]}])['RouteTables'][0]['Associations'][0]['RouteTableId']
  ext_route_table = ec2_client.describe_route_tables(Filters=[{'Name': 'vpc-id', 'Values': [ext_id]}])['RouteTables'][0]['Associations'][0]['RouteTableId']
  
  # create route from internal VPC to external
  ec2_client.create_route(
    DestinationCidrBlock='10.0.0.0/16',
    RouteTableId=int_route_table,
    VpcPeeringConnectionId=vpc_peering_connection.id
  )
  
  # create route from external VPC to internal
  ec2_client.create_route(
    DestinationCidrBlock='10.1.0.0/16',
    RouteTableId=ext_route_table,
    VpcPeeringConnectionId=vpc_peering_connection.id
  )
  
 
  # create securitygroups for external vpc & internal vpc
  securitygroup_ext = ec2_resource.create_security_group(GroupName='ALLOW-ALL-2', Description='Allow all', VpcId=ext_id)
  securitygroup_int = ec2_resource.create_security_group(GroupName='ALLOW-ALL-2', Description='Allow all', VpcId=int_id)
  
  # allow relevant sources to access (my IP and both VPCs)
  securitygroup_ext.authorize_ingress(CidrIp='217.132.252.35/0', IpProtocol='-1')
  securitygroup_ext.authorize_ingress(CidrIp='10.1.0.0/16', IpProtocol='-1')
  securitygroup_int.authorize_ingress(CidrIp='10.0.0.0/16', IpProtocol='-1')
  

def create_k8s_cluster():
  # get security group
  int_id = ec2_client.describe_vpcs(Filters=[{'Name':'cidr', 'Values':['10.1.0.0/16']}])['Vpcs'][0]['VpcId']
  sec = ec2_client.describe_security_groups(Filters=[{'Name':'vpc-id', 'Values':[int_id]}])['SecurityGroups'][0]['GroupId']
  
  # get subnets IDs
  subnet_1 = ec2_client.describe_subnets(Filters=[{'Name': 'cidr-block', 'Values': ['10.1.1.0/25']}])['Subnets'][0]['SubnetId']
  subnet_2 = ec2_client.describe_subnets(Filters=[{'Name': 'cidr-block', 'Values': ['10.1.4.0/25']}])['Subnets'][0]['SubnetId']
  
  eks_client.create_cluster(
    name='internal-clus',
    roleArn='arn:aws:iam::989801891188:role/idan-role',
    resourcesVpcConfig={
        'subnetIds': [
            subnet_1,
            subnet_2,
        ],
        'securityGroupIds': [
            sec,
        ],
        'endpointPrivateAccess': True
    },
  )
  
  # create tags to create nodegroups in them
  subnet = ec2_resource.Subnet(subnet_1)
  subnet.create_tags(
    Tags=[
        {
            'Key': 'kubernetes.io/cluster/internal-clus', 
            'Value': 'shared'
        },
    ]
  )
  
  vpc = ec2_resource.Vpc(int_id)
  vpc.create_tags(
    Tags=[
        {
            'Key': 'kubernetes.io/cluster/internal-clus', 
            'Value': 'shared'
        },
    ]
  )
  
  subnet = ec2_resource.Subnet(subnet_2)
  subnet.create_tags(
    Tags=[
        {
            'Key': 'kubernetes.io/cluster/internal-clus', 
            'Value': 'shared'
        },
    ]
  )
  
  eks_client.create_nodegroup(
    clusterName='internal-clus',
    nodegroupName='internal-clus-nodegroup-1',
    scalingConfig={
        'minSize': 1,
        'maxSize': 2,
        'desiredSize': 1
    },
    subnets=[
        subnet_1,
        subnet_2
    ],
    instanceTypes=[
        't3.medium',
    ],
    amiType='AL2_x86_64',
    remoteAccess={
        'ec2SshKey': 'idan_keypair',
        'sourceSecurityGroups': [
            sec,
        ]
    },
    nodeRole='arn:aws:iam::989801891188:role/eks-node-group-instance-role-NodeInstanceRole-1FS822Z5JMUNI',
  )


  
  
# finally, run the functions
create_external_vpc()
create_internal_vpc()
establish_conectivity()
