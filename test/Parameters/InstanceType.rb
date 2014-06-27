  parameter 'InstanceType',
            :Description => 'WebServer EC2 instance type',
            :Type => 'String',
            :Default => 'm1.small',
            :AllowedValues => %w(t1.micro m1.small m1.medium m1.large m1.xlarge m2.xlarge m2.2xlarge m2.4xlarge m3.xlarge m3.2xlarge c1.medium c1.xlarge cc1.4xlarge cc2.8xlarge cg1.4xlarge),
            :ConstraintDescription => 'must be a valid EC2 instance type.'

