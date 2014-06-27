  resource 'HostKeys', :Type => 'AWS::IAM::AccessKey', :Properties => {
      :UserName => { :Ref => 'ChefServerUser' },
  }

