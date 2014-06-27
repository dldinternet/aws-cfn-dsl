  output 'ChefSecurityGroup',
         :Description => 'EC2 Security Group with access to Opscode chef server',
         :Value => { :Ref => 'ChefClientSecurityGroup' }

