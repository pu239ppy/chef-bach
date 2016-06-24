name             'bach_wrapper'
maintainer       'Bloomberg LP'
maintainer_email 'compute@bloomberg.net'
license          'All rights reserved'
description      'Top-level chef-bach wrapper'
long_description 'Top-level chef-bach wrapper'
<<<<<<< HEAD
version          '0.1.0'

depends 'bach_common', '= 0.1.0'
depends 'bach_krb5', '= 0.1.0'
depends 'bach_spark', '= 0.1.0'
depends 'bcpc', '= 0.1.0'
depends 'bcpc-hadoop', '= 0.1.0'
depends 'bcpc_jmxtrans', '= 0.1.0'
depends 'hannibal', '= 0.1.0'
depends 'kafka-bcpc', '= 0.1.0'
=======
version          '1.0.0'

depends 'bach_common', '= 1.0.0'
depends 'bach_krb5', '= 1.0.0'
depends 'bach_spark', '= 1.0.0'
depends 'bcpc', '= 1.0.0'
depends 'bcpc-hadoop', '= 1.0.0'
depends 'bcpc_jmxtrans', '= 1.0.0'
depends 'hannibal', '= 1.0.0'
depends 'kafka-bcpc', '= 1.0.0'
>>>>>>> release-1.0

# These dependencies are added only to prevent a transitive dependency on a newer cookbook version which does not support Chef 11.x.
depends 'build-essential', '~> 3.2.0'
depends 'ohai', '~> 3.0.1'
depends 'windows', '~> 1.36.6'
