  parameter 'KeyName',
            :Description => 'Name of an existing EC2 KeyPair to enable SSH access to the web server',
            :Type => 'String',
            :MinLength => '1',
            :MaxLength => '255',
            :AllowedPattern => '[\\x20-\\x7E]*',
            :ConstraintDescription => 'can contain only ASCII characters.'

