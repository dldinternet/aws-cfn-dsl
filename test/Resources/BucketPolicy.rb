  resource 'BucketPolicy', :Type => 'AWS::S3::BucketPolicy', :Properties => {
      :PolicyDocument => {
          :Version => '2008-10-17',
          :Id => 'WritePolicy',
          :Statement => [
              {
                  :Sid => 'WriteAccess',
                  :Action => [ 's3:PutObject' ],
                  :Effect => 'Allow',
                  :Resource => {
                      :'Fn::Join' => [
                          '',
                          [
                              'arn:aws:s3:::',
                              { :Ref => 'PrivateKeyBucket' },
                              '/*',
                          ],
                      ],
                  },
                  :Principal => {
                      :AWS => { :'Fn::GetAtt' => [ 'ChefServerUser', 'Arn' ] },
                  },
              },
          ],
      },
      :Bucket => { :Ref => 'PrivateKeyBucket' },
  }

