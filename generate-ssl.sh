#!/bin/bash

. /path/to/some.config

echo -n "Enter the domain name and press [ENTER]: "
read domain

openssl genrsa -out /etc/ssl/private/$domain.key 2048
openssl req -new -key /etc/ssl/private/$domain.key -out $CSRLocation$domain.csr -subj '/C=$Country/ST=$State/L=$Location/O=$Organization/CN=$domain/emailAddress=$EmailAddress' \


cat >$SANConfigLocation$domain.ext <<EOL
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = $domain
EOL

openssl x509 -req -in $CSRLocation$domain.csr -CA $CertLocationmyCA.pem -CAkey $CertLocationmyCA.key -CAcreateserial -out $CertLocation$domain.crt -days 1825 -sha256 -extfile $SANConfigLocation$domain.ext

echo -n "Enter the DocumentRoot folder (e.g /var/www/html/example.com/public) and press [ENTER]: "
read DocumentRoot

cat >$ApacheSitesAvailable$domain.conf <<EOL
<VirtualHost *:80>
	ServerAdmin $EmailAddress
	DocumentRoot $DocumentRoot

	ServerName $domain
	ServerAlias $domain

	ErrorLog \${APACHE_LOG_DIR}/$domain-errors.log
	CustomLog \${APACHE_LOG_DIR}/$domain-access.log combined

	Redirect permanent "/" "https://$domain/"
</VirtualHost>
EOL

a2dissite $domain.conf
a2ensite $domain.conf

cat >$ApacheSitesAvailable$domain-ssl.conf <<EOL
<IfModule mod_ssl.c>
	<VirtualHost _default_:443>
		ServerAdmin $EmailAddress

		DocumentRoot $DocumentRoot

		ServerName $domain
		ServerAlias $domain

		<Directory "$DocumentRoot">
			Options Indexes MultiViews FollowSymLinks
			AllowOverride All
        		Order allow,deny
		        Allow from all
		</Directory>

		#LogLevel info ssl:warn

		ErrorLog \${APACHE_LOG_DIR}/$domain-ssl-error.log
		CustomLog \${APACHE_LOG_DIR}/$domain-ssl-access.log combined

		#Include conf-available/serve-cgi-bin.conf

		SSLEngine on

		SSLCertificateFile	$CertLocation$domain.crt
		SSLCertificateKeyFile /etc/ssl/private/$domain.key

		<FilesMatch "\.(cgi|shtml|phtml|php)$">
				SSLOptions +StdEnvVars
		</FilesMatch>
		<Directory /usr/lib/cgi-bin>
				SSLOptions +StdEnvVars
		</Directory>

	</VirtualHost>
</IfModule>
EOL

a2dissite $domain-ssl.conf
a2ensite $domain-ssl.conf

apachectl configtest
apachectl restart