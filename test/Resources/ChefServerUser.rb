  resource 'ChefServerUser', :Type => 'AWS::IAM::User', :Properties => {
      :Path => '/',
      :Policies => [
          {
              :PolicyName => 'root',
              :PolicyDocument => {
                  :Statement => [
                      {
                          :Effect => 'Allow',
                          :Action => [ 'cloudformation:DescribeStackResource', 's3:Put' ],
                          :Resource => '*',
                      },
                  ],
              },
          },
      ],
  }

