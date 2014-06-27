  resource 'ChefClientSecurityGroup', :Type => 'AWS::EC2::SecurityGroup', :Properties => { :GroupDescription => 'Group with access to Chef Server' }

