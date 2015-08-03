require 'openssl'
name = "CARBIDE-SERVER"
digest = OpenSSL::Digest::SHA256.base64digest(name)
p digest
name = name + "--" + digest
p name
