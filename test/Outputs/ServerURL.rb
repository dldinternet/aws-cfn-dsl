  output 'ServerURL',
         :Description => 'URL of newly created Opscode chef server',
         :Value => {
             :'Fn::Join' => [
                 '',
                 [
                     'https://',
                     { :'Fn::GetAtt' => [ 'ChefServer', 'PublicDnsName' ] },
                     ':443',
                 ],
             ],
         }

