  resource 'PrivateKeyBucket', :Type => 'AWS::S3::Bucket', :DeletionPolicy => 'Delete', :Properties => { :AccessControl => 'Private' }

