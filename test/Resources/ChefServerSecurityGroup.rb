  resource 'ChefServerSecurityGroup', :Type => 'AWS::EC2::SecurityGroup', :Properties => {
      :GroupDescription => 'Open up SSH access plus Chef Server required ports',
      :SecurityGroupIngress => [
          {
              :IpProtocol => 'tcp',
              :FromPort => '22',
              :ToPort => '22',
              :CidrIp => { :Ref => 'SSHLocation' },
          },
          {
              :IpProtocol => 'tcp',
              :FromPort => '443',
              :ToPort => '443',
              :SourceSecurityGroupName => { :Ref => 'ChefClientSecurityGroup' },
          },
          { :IpProtocol => 'tcp', :FromPort => '443', :ToPort => '443', :CidrIp => '0.0.0.0/0' },
      ],
  }

