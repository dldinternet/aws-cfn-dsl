#!/usr/bin/env ruby

$:.unshift(File.dirname(__FILE__))
$:.unshift File.absolute_path("#{File.dirname(__FILE__)}/../lib")
require 'bundler/setup'
require 'aws/cfn/dsl/template'

template do

  value :AWSTemplateFormatVersion => '2010-09-09'

  value :Description => 'Sample template to bring up an Opscode Chef Server using the Opscode debian files for installation. This configuration creates and starts the Chef Server with the WebUI enabled, initializes knife and uploads specified cookbooks and roles to the chef server. A WaitCondition is used to hold up the stack creation until the application is deployed. **WARNING** This template creates one or more Amazon EC2 instances. You will be billed for the AWS resources used if you create a stack from this template.'

  # Mappings
  mapping 'AWSRegion2AMI'

  # Parameters
  parameter 'KeyName'
  parameter 'CookbookLocation'
  parameter 'RoleLocation'
  parameter 'InstanceType'
  parameter 'SSHLocation'

  # Resources
  resource 'ChefServerUser'
  resource 'HostKeys'
  resource 'ChefServer'
  resource 'ChefServerSecurityGroup'
  resource 'ChefClientSecurityGroup'
  resource 'PrivateKeyBucket'
  resource 'BucketPolicy'
  resource 'ChefServerWaitHandle'
  resource 'ChefServerWaitCondition'

  # Outputs
  output 'ServerURL'
  output 'ChefSecurityGroup'
  output 'ValidationKeyBucket'

end.exec!
