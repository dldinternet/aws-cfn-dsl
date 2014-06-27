  resource 'ChefServerWaitCondition', :Type => 'AWS::CloudFormation::WaitCondition', :DependsOn => 'ChefServer', :Properties => {
      :Handle => { :Ref => 'ChefServerWaitHandle' },
      :Timeout => '1200',
  }

