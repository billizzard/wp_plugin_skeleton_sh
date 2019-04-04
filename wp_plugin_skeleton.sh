#!/bin/bash

QUOTE_COLOR='\033[0;34m'
SUCCESS_COLOR='\033[0;32m'
LINK_COLOR='\033[0;35m'
NO_COLOR='\033[0m'

if [ "$1" == "--links" ]; then
	printf "Developer guidelines: ${LINK_COLOR}https://developer.wordpress.org/plugins/wordpress-org/detailed-plugin-guidelines/"
	printf "\n${NO_COLOR}How work README.txt: ${LINK_COLOR}https://developer.wordpress.org/plugins/wordpress-org/how-your-readme-txt-works/"
	printf "\n${NO_COLOR}How use subversion in wp repository: ${LINK_COLOR}https://developer.wordpress.org/plugins/wordpress-org/how-to-use-subversion/"
	printf "\n${NO_COLOR}How add icon and banner to plugin: ${LINK_COLOR}https://developer.wordpress.org/plugins/wordpress-org/plugin-assets/"
else

printf '\nHi, this script allow you create skeleton for your awesome wordpress plugin.'
printf "First you need to choose a name for your future plugin.
\nIf you want to publish a plugin, remember, the name must be unique and preferably long. Quote:
\n${QUOTE_COLOR}A good way to do this is with a prefix.
\nDon't try to use two letter slugs anymore. We have over 60 THOUSAND plugins on WordPress.org alone, you’re going to run into conflicts.
\nSimilarly, don't use __ (double underscores), wp_ , or _ (single underscore) as a prefix. Those are reserved for WordPress itself. You can use them inside your classes, but not as stand-alone function.
\nRemember: Good names are unique and distinct."

printf "\n\n${NO_COLOR}Enter plugin name (Default: My Awesome Plugin)*:"
read PLUGIN_NAME

printf "\n\n${QUOTE_COLOR} The home page of the plugin, which should be a unique URL, preferably on your own website. This must be unique to your plugin. You cannot use a WordPress.org URL here."
printf "\n${NO_COLOR}Plugin URI:"
read PLUGIN_URI

printf "\n\n${QUOTE_COLOR} The name of the plugin author. Multiple authors may be listed using commas."
printf "\n${NO_COLOR}Enter author name (Example: John Doe):"
read AUTHOR_NAME

printf "\n\nEnter author email:"
read AUTHOR_EMAIL

printf "\n\n${QUOTE_COLOR} The author’s website or profile on another website, such as WordPress.org."
printf "\n${NO_COLOR}Enter author uri:"
read AUTHOR_URI

printf "\n\n${QUOTE_COLOR}Sometimes a plug-in needs a table in the database. It needs to be added to the script to Activate and Uninstall the plugin."
printf "\n${NO_COLOR}Do you need an example with a test table in a database? (y/n, Default: n):"
read DATABASE_NEED

printf "\n\n${QUOTE_COLOR}Docker will allow you to immediately deploy a WordPress site with the plug-in already installed. The site will be available at http://localhost/. \nIf you have not worked with a docker before, select n."
printf "\n${NO_COLOR}Do you want use Docker? (y/n, Default: n):"
read DOCKER_NEED

PLUGIN_NAME=${PLUGIN_NAME:-My Awesome Plugin}
PLUGIN_URI=${PLUGIN_URI:-PluginUri}
AUTHOR_NAME=${AUTHOR_NAME:-AuthorName}
AUTHOR_EMAIL=${AUTHOR_EMAIL:-AuthorEmail}
AUTHOR_URI=${AUTHOR_URI:-AuthorUri}
DOCKER_NEED=${DOCKER_NEED:-n}
DATABASE_NEED=${DATABASE_NEED:-n}
PLUGIN_SLUG=$(echo "${PLUGIN_NAME}" | sed -r 's/\<./\U&/g')
PLUGIN_FOLDER=$(echo "${PLUGIN_NAME}" | sed -r 's/ /_/g')
PLUGIN_FOLDER=$(echo "${PLUGIN_FOLDER}" | sed -e 's/\(.*\)/\L\1/')
PLUGIN_NAME_CONST=$(echo "${PLUGIN_FOLDER}" | sed -e 's/\(.*\)/\U\1/')
PLUGIN_SLUG=$(echo "${PLUGIN_SLUG}" | sed -r 's/ //g')

if [ $DOCKER_NEED = 'y' ]; then
	echo 'Start create project skeleton'
	mkdir wp_${PLUGIN_FOLDER}
	cd wp_${PLUGIN_FOLDER}
	mkdir nginx php-fpm-wordpress

	echo "Create docker-compose.yml file"
	touch docker-compose.yml
	cat <<EOT >> docker-compose.yml
version: "3.3"

services:
    nginx:
        build: ./nginx
        links:
            - php-fpm-wordpress
        ports:
            - 80:80
            - 443:443
        volumes:
            - \${DB_PATH_HOST}/nginx/logs:/var/log/nginx
            - app-volume:/var/www/wordpress
            - ./${PLUGIN_FOLDER}:\${APP_PATH_HOST}/wordpress/wp-content/plugins/${PLUGIN_FOLDER}

    db:
        image: mysql:5.7
        volumes:
          - \${DB_PATH_HOST}/mysql:/var/lib/mysql
          - \${DB_PATH_HOST}/wp.cnf:/etc/mysql/conf.d/wp.cnf
          - .:\${APP_PATH_HOST}
        ports:
            - 3306:3306
        environment:
            MYSQL_ROOT_PASSWORD: \${MYSQL_ROOT_PASSWORD}
            MYSQL_DATABASE: \${MYSQL_DATABASE}
            MYSQL_USER: \${MYSQL_USER}
            MYSQL_PASSWORD: \${MYSQL_PASSWORD}

    php-fpm-wordpress:
        build: ./php-fpm-wordpress
        volumes:
            - ./${PLUGIN_FOLDER}:\${APP_PATH_HOST}/wordpress/wp-content/plugins/${PLUGIN_FOLDER}
            - \${DB_PATH_HOST}/uploads.ini:/usr/local/etc/php/conf.d/uploads.ini
            - app-volume:\${APP_PATH_HOST}/wordpress
        depends_on:
            - db
        environment:
            WORDPRESS_DB_NAME: \${MYSQL_DATABASE}
            WORDPRESS_DB_HOST: db:3306
            WORDPRESS_DB_USER: \${MYSQL_USER}
            WORDPRESS_DB_PASSWORD: \${MYSQL_PASSWORD}
        ports:
            - 9000:9000

volumes:
     app-volume:

EOT

	echo "Create nginx/nginx.conf file"
	touch nginx/nginx.conf
	cat <<EOT >> nginx/nginx.conf
server {
    gzip on;
    gzip_buffers 16 8k;
    gzip_comp_level 2;
    gzip_min_length 1024;
    gzip_types text/css text/plain text/json text/x-js text/javascript text/xml application/json application/x-javascript application/xml application/xml+rss application/javascript;
    gzip_disable "msie6";
    gzip_vary on;
    gzip_http_version 1.0;
    listen 80;
    keepalive_timeout   60;
    server_name localhost;
    root /var/www/wordpress;
    index index.php index.html index.htm;
    access_log /var/log/nginx/wp.log;
    error_log /var/log/nginx/wp-error.log;
    client_body_timeout 3000;
    client_max_body_size 64m;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    error_page 404 /404.html;
    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
         root /usr/share/nginx/html;
    }

    location ~ \.php\$ {
     fastcgi_split_path_info ^(.+\.php)(/.+)\$;
     fastcgi_pass  php-fpm-wordpress:9000;
     fastcgi_index index.php;
     include fastcgi_params;
     fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
     fastcgi_param PATH_INFO \$fastcgi_path_info;
    }
}

EOT

	echo "Create nginx/Dockerfile file"
	touch nginx/Dockerfile
	cat <<EOT >> nginx/Dockerfile
FROM nginx

RUN apt-get update \\
 && apt-get install -y git nano curl zlib1g-dev \\
         libfreetype6-dev \\
         libjpeg62-turbo-dev \\
         libmcrypt-dev \\
         libpng-dev \\
         libxml2-dev

ADD nginx.conf /etc/nginx/sites-available/
RUN ln -s /etc/nginx/sites-available/nginx.conf /etc/nginx/conf.d/
RUN rm -rf /etc/nginx/conf.d/default.conf
WORKDIR /var/www/wordpress
EOT

	echo "Create php-fpm-wordpress/Dockerfile file"
	touch php-fpm-wordpress/Dockerfile
	cat <<EOT >> php-fpm-wordpress/Dockerfile
FROM wordpress:4.9.8-php7.1-fpm

RUN apt-get update && apt-get install -y \\
        libfreetype6-dev \\
        libjpeg62-turbo-dev \\
        libmcrypt-dev \\
        libpng-dev \\
        libxml2-dev \\
        nano libssl-dev libcurl4-openssl-dev pkg-config \\
    && docker-php-ext-install -j\$(nproc) mysqli mbstring pdo pdo_mysql soap curl \\
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \\
    && docker-php-ext-install -j\$(nproc) gd \\
    && pecl install xdebug \\
 && curl -sS https://getcomposer.org/installer \\
  | php -- --install-dir=/usr/local/bin --filename=composer

RUN { \
        echo '[xdebug]'; \\
        echo 'zend_extension=/usr/local/lib/php/extensions/no-debug-non-zts-20160303/xdebug.so'; \\
        echo "error_reporting = E_ALL"; \\
        echo "display_startup_errors = On"; \\
        echo "display_errors = On"; \\
        echo "xdebug.remote_enable=1"; \\
        echo "xdebug.remote_connect_back=1"; \\
        echo "xdebug.idekey='PHPSTORM'"; \\
        echo "xdebug.remote_port=9001"; \\
    } > /usr/local/etc/php/conf.d/xdebug.ini

WORKDIR /var/www/wordpress
EOT

	echo "Create .env file"
	touch .env
	cat <<EOT >> .env
#PATHS
DB_PATH_HOST=./.data
APP_PATH_HOST=/var/www

# MySQL
MYSQL_DATABASE=wp_${PLUGIN_FOLDER}
MYSQL_USER=user_root
MYSQL_PASSWORD=root
MYSQL_ROOT_PASSWORD=root
EOT

fi

echo 'Start create plugin skeleton'
echo "Create folder ${PLUGIN_FOLDER}"
mkdir $PLUGIN_FOLDER
cd $PLUGIN_FOLDER
echo "Create folders structure"
mkdir admin
mkdir admin/js
mkdir admin/partials
mkdir admin/css
mkdir public
mkdir public/css
mkdir public/js
mkdir public/partials
mkdir includes
mkdir languages

echo "Create index.php file"
touch index.php
cat <<EOT >> index.php
<?php
/**
 * The plugin bootstrap file
 *
 * This file is read by WordPress to generate the plugin information in the plugin
 * admin area. This file also includes all of the dependencies used by the plugin,
 * registers the activation and deactivation functions, and defines a function
 * that starts the plugin.
 *
 * @link              ${AUTHOR_URI}
 * @since             1.0.0
 * @package           ${PLUGIN_SLUG}
 *
 * @wordpress-plugin
 * Plugin Name:       ${PLUGIN_NAME}
 * Plugin URI:        ${PLUGIN_URI}
 * Description:       This is a short description of what the plugin does. It is displayed in the WordPress admin area.
 * Version:           1.0.0
 * Author:            ${AUTHOR_NAME}
 * Author URI:        ${AUTHOR_URI}
 * License:           GPL-2.0+
 * License URI:       http://www.gnu.org/licenses/gpl-2.0.txt
 * Domain Path:       /languages
 */

// If this file is called directly, abort.
if (!defined('WPINC')) {
    die;
}

/**
 * Currently plugin version.
 * Start at version 1.0.0 and use SemVer - https://semver.org
 * Rename this for your plugin and update it as you release new versions.
 */
define('${PLUGIN_NAME_CONST}_VERSION', '1.0.0');

/**
 * The code that runs during plugin activation.
 */
function activate${PLUGIN_SLUG}()
{
    require_once plugin_dir_path(__FILE__) . 'includes/${PLUGIN_SLUG}Activator.php';
    ${PLUGIN_SLUG}Activator::activate();
}

/**
 * The code that runs during plugin deactivation.
 */
function deactivate${PLUGIN_SLUG}()
{
    require_once plugin_dir_path(__FILE__) . 'includes/${PLUGIN_SLUG}Deactivator.php';
    ${PLUGIN_SLUG}Deactivator::deactivate();
}

register_activation_hook(__FILE__, 'activate${PLUGIN_SLUG}');
register_deactivation_hook(__FILE__, 'deactivate${PLUGIN_SLUG}');

/**
 * The core plugin class that is used to define internationalization,
 * admin-specific hooks, and public-facing site hooks.
 */
require plugin_dir_path(__FILE__) . 'includes/${PLUGIN_SLUG}.php';

/**
 * Begins execution of the plugin.
 *
 * Since everything within the plugin is registered via hooks,
 * then kicking off the plugin from this point in the file does
 * not affect the page life cycle.
 *
 * @since    1.0.0
 */
function run${PLUGIN_SLUG}()
{
    \$plugin = new ${PLUGIN_SLUG}();
    \$plugin->run();
}

run${PLUGIN_SLUG}();

EOT

echo 'Create README.txt'
touch README.txt
cat <<EOT >> README.txt
=== ${PLUGIN_NAME} ===
Contributors: (this should be a list of wordpress.org userid's)
Donate link: ${AUTHOR_URI}
Tags: comments, spam
Requires at least: 3.0.1
Tested up to: 3.4
Stable tag: 4.3
License: GPLv2 or later
License URI: http://www.gnu.org/licenses/gpl-2.0.html

Here is a short description of the plugin.  This should be no more than 150 characters.  No markup here.

== Description ==

This is the long description.  No limit, and you can use Markdown (as well as in the following sections).

For backwards compatibility, if this section is missing, the full length of the short description will be used, and
Markdown parsed.

A few notes about the sections above:

*   "Contributors" is a comma separated list of wp.org/wp-plugins.org usernames
*   "Tags" is a comma separated list of tags that apply to the plugin
*   "Requires at least" is the lowest version that the plugin will work on
*   "Tested up to" is the highest version that you've *successfully used to test the plugin*. Note that it might work on
higher versions... this is just the highest one you've verified.
*   Stable tag should indicate the Subversion "tag" of the latest stable version, or "trunk," if you use \`/trunk/\` for
stable.

    Note that the \`readme.txt\` of the stable tag is the one that is considered the defining one for the plugin, so
if the \`/trunk/readme.txt\` file says that the stable tag is \`4.3\`, then it is \`/tags/4.3/readme.txt\` that'll be used
for displaying information about the plugin.  In this situation, the only thing considered from the trunk \`readme.txt\`
is the stable tag pointer.  Thus, if you develop in trunk, you can update the trunk \`readme.txt\` to reflect changes in
your in-development version, without having that information incorrectly disclosed about the current stable version
that lacks those changes -- as long as the trunk's \`readme.txt\` points to the correct stable tag.

    If no stable tag is provided, it is assumed that trunk is stable, but you should specify "trunk" if that's where
you put the stable version, in order to eliminate any doubt.

== Installation ==

This section describes how to install the plugin and get it working.

e.g.

1. From WP admin > Plugins > Add New
2. Search «${PLUGIN_NAME}» under search and hit Enter
3. Press «Install Now»
4. Press «Activate plugin»

== Frequently Asked Questions ==

= A question that someone might have =

An answer to that question.

= What about foo bar? =

Answer to foo bar dilemma.

== Screenshots ==

1. This screen shot description corresponds to screenshot-1.(png|jpg|jpeg|gif). Note that the screenshot is taken from
the /assets directory or the directory that contains the stable readme.txt (tags or trunk). Screenshots in the /assets
directory take precedence. For example, \`/assets/screenshot-1.png\` would win over \`/tags/4.3/screenshot-1.png\`
(or jpg, jpeg, gif).
2. This is the second screen shot

== Changelog ==

= 1.0 =
* A change since the previous version.
* Another change.

= 0.5 =
* List versions from most recent at top to oldest at bottom.

== Upgrade Notice ==

= 1.0 =
Upgrade notices describe the reason a user should upgrade.  No more than 300 characters.

= 0.5 =
This version fixes a security related bug.  Upgrade immediately.

== Arbitrary section ==

You may provide arbitrary sections, in the same format as the ones above.  This may be of use for extremely complicated
plugins where more information needs to be conveyed that doesn't fit into the categories of "description" or
"installation."  Arbitrary sections will be shown below the built-in sections outlined above.

== A brief Markdown Example ==

Ordered list:

1. Some feature
1. Another feature
1. Something else about the plugin

Unordered list:

* something
* something else
* third thing

Here's a link to [WordPress](http://wordpress.org/ "Your favorite software") and one to [Markdown's Syntax Documentation][markdown syntax].
Titles are optional, naturally.

[markdown syntax]: http://daringfireball.net/projects/markdown/syntax
            "Markdown is what the parser uses to process much of the readme file"

Markdown uses email style notation for blockquotes and I've been told:
> Asterisks for *emphasis*. Double it up  for **strong**.

\`<?php code(); // goes in backticks ?>\`

EOT

echo 'Create LICENSE.txt'
touch LICENSE.txt
cat <<EOT >> LICENSE.txt
                    GNU GENERAL PUBLIC LICENSE
                       Version 2, June 1991

 Copyright (C) 1989, 1991 Free Software Foundation, Inc.,
 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 Everyone is permitted to copy and distribute verbatim copies
 of this license document, but changing it is not allowed.

                            Preamble

  The licenses for most software are designed to take away your
freedom to share and change it.  By contrast, the GNU General Public
License is intended to guarantee your freedom to share and change free
software--to make sure the software is free for all its users.  This
General Public License applies to most of the Free Software
Foundation's software and to any other program whose authors commit to
using it.  (Some other Free Software Foundation software is covered by
the GNU Lesser General Public License instead.)  You can apply it to
your programs, too.

  When we speak of free software, we are referring to freedom, not
price.  Our General Public Licenses are designed to make sure that you
have the freedom to distribute copies of free software (and charge for
this service if you wish), that you receive source code or can get it
if you want it, that you can change the software or use pieces of it
in new free programs; and that you know you can do these things.

  To protect your rights, we need to make restrictions that forbid
anyone to deny you these rights or to ask you to surrender the rights.
These restrictions translate to certain responsibilities for you if you
distribute copies of the software, or if you modify it.

  For example, if you distribute copies of such a program, whether
gratis or for a fee, you must give the recipients all the rights that
you have.  You must make sure that they, too, receive or can get the
source code.  And you must show them these terms so they know their
rights.

  We protect your rights with two steps: (1) copyright the software, and
(2) offer you this license which gives you legal permission to copy,
distribute and/or modify the software.

  Also, for each author's protection and ours, we want to make certain
that everyone understands that there is no warranty for this free
software.  If the software is modified by someone else and passed on, we
want its recipients to know that what they have is not the original, so
that any problems introduced by others will not reflect on the original
authors' reputations.

  Finally, any free program is threatened constantly by software
patents.  We wish to avoid the danger that redistributors of a free
program will individually obtain patent licenses, in effect making the
program proprietary.  To prevent this, we have made it clear that any
patent must be licensed for everyone's free use or not licensed at all.

  The precise terms and conditions for copying, distribution and
modification follow.

                    GNU GENERAL PUBLIC LICENSE
   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION

  0. This License applies to any program or other work which contains
a notice placed by the copyright holder saying it may be distributed
under the terms of this General Public License.  The "Program", below,
refers to any such program or work, and a "work based on the Program"
means either the Program or any derivative work under copyright law:
that is to say, a work containing the Program or a portion of it,
either verbatim or with modifications and/or translated into another
language.  (Hereinafter, translation is included without limitation in
the term "modification".)  Each licensee is addressed as "you".

Activities other than copying, distribution and modification are not
covered by this License; they are outside its scope.  The act of
running the Program is not restricted, and the output from the Program
is covered only if its contents constitute a work based on the
Program (independent of having been made by running the Program).
Whether that is true depends on what the Program does.

  1. You may copy and distribute verbatim copies of the Program's
source code as you receive it, in any medium, provided that you
conspicuously and appropriately publish on each copy an appropriate
copyright notice and disclaimer of warranty; keep intact all the
notices that refer to this License and to the absence of any warranty;
and give any other recipients of the Program a copy of this License
along with the Program.

You may charge a fee for the physical act of transferring a copy, and
you may at your option offer warranty protection in exchange for a fee.

  2. You may modify your copy or copies of the Program or any portion
of it, thus forming a work based on the Program, and copy and
distribute such modifications or work under the terms of Section 1
above, provided that you also meet all of these conditions:

    a) You must cause the modified files to carry prominent notices
    stating that you changed the files and the date of any change.

    b) You must cause any work that you distribute or publish, that in
    whole or in part contains or is derived from the Program or any
    part thereof, to be licensed as a whole at no charge to all third
    parties under the terms of this License.

    c) If the modified program normally reads commands interactively
    when run, you must cause it, when started running for such
    interactive use in the most ordinary way, to print or display an
    announcement including an appropriate copyright notice and a
    notice that there is no warranty (or else, saying that you provide
    a warranty) and that users may redistribute the program under
    these conditions, and telling the user how to view a copy of this
    License.  (Exception: if the Program itself is interactive but
    does not normally print such an announcement, your work based on
    the Program is not required to print an announcement.)

These requirements apply to the modified work as a whole.  If
identifiable sections of that work are not derived from the Program,
and can be reasonably considered independent and separate works in
themselves, then this License, and its terms, do not apply to those
sections when you distribute them as separate works.  But when you
distribute the same sections as part of a whole which is a work based
on the Program, the distribution of the whole must be on the terms of
this License, whose permissions for other licensees extend to the
entire whole, and thus to each and every part regardless of who wrote it.

Thus, it is not the intent of this section to claim rights or contest
your rights to work written entirely by you; rather, the intent is to
exercise the right to control the distribution of derivative or
collective works based on the Program.

In addition, mere aggregation of another work not based on the Program
with the Program (or with a work based on the Program) on a volume of
a storage or distribution medium does not bring the other work under
the scope of this License.

  3. You may copy and distribute the Program (or a work based on it,
under Section 2) in object code or executable form under the terms of
Sections 1 and 2 above provided that you also do one of the following:

    a) Accompany it with the complete corresponding machine-readable
    source code, which must be distributed under the terms of Sections
    1 and 2 above on a medium customarily used for software interchange; or,

    b) Accompany it with a written offer, valid for at least three
    years, to give any third party, for a charge no more than your
    cost of physically performing source distribution, a complete
    machine-readable copy of the corresponding source code, to be
    distributed under the terms of Sections 1 and 2 above on a medium
    customarily used for software interchange; or,

    c) Accompany it with the information you received as to the offer
    to distribute corresponding source code.  (This alternative is
    allowed only for noncommercial distribution and only if you
    received the program in object code or executable form with such
    an offer, in accord with Subsection b above.)

The source code for a work means the preferred form of the work for
making modifications to it.  For an executable work, complete source
code means all the source code for all modules it contains, plus any
associated interface definition files, plus the scripts used to
control compilation and installation of the executable.  However, as a
special exception, the source code distributed need not include
anything that is normally distributed (in either source or binary
form) with the major components (compiler, kernel, and so on) of the
operating system on which the executable runs, unless that component
itself accompanies the executable.

If distribution of executable or object code is made by offering
access to copy from a designated place, then offering equivalent
access to copy the source code from the same place counts as
distribution of the source code, even though third parties are not
compelled to copy the source along with the object code.

  4. You may not copy, modify, sublicense, or distribute the Program
except as expressly provided under this License.  Any attempt
otherwise to copy, modify, sublicense or distribute the Program is
void, and will automatically terminate your rights under this License.
However, parties who have received copies, or rights, from you under
this License will not have their licenses terminated so long as such
parties remain in full compliance.

  5. You are not required to accept this License, since you have not
signed it.  However, nothing else grants you permission to modify or
distribute the Program or its derivative works.  These actions are
prohibited by law if you do not accept this License.  Therefore, by
modifying or distributing the Program (or any work based on the
Program), you indicate your acceptance of this License to do so, and
all its terms and conditions for copying, distributing or modifying
the Program or works based on it.

  6. Each time you redistribute the Program (or any work based on the
Program), the recipient automatically receives a license from the
original licensor to copy, distribute or modify the Program subject to
these terms and conditions.  You may not impose any further
restrictions on the recipients' exercise of the rights granted herein.
You are not responsible for enforcing compliance by third parties to
this License.

  7. If, as a consequence of a court judgment or allegation of patent
infringement or for any other reason (not limited to patent issues),
conditions are imposed on you (whether by court order, agreement or
otherwise) that contradict the conditions of this License, they do not
excuse you from the conditions of this License.  If you cannot
distribute so as to satisfy simultaneously your obligations under this
License and any other pertinent obligations, then as a consequence you
may not distribute the Program at all.  For example, if a patent
license would not permit royalty-free redistribution of the Program by
all those who receive copies directly or indirectly through you, then
the only way you could satisfy both it and this License would be to
refrain entirely from distribution of the Program.

If any portion of this section is held invalid or unenforceable under
any particular circumstance, the balance of the section is intended to
apply and the section as a whole is intended to apply in other
circumstances.

It is not the purpose of this section to induce you to infringe any
patents or other property right claims or to contest validity of any
such claims; this section has the sole purpose of protecting the
integrity of the free software distribution system, which is
implemented by public license practices.  Many people have made
generous contributions to the wide range of software distributed
through that system in reliance on consistent application of that
system; it is up to the author/donor to decide if he or she is willing
to distribute software through any other system and a licensee cannot
impose that choice.

This section is intended to make thoroughly clear what is believed to
be a consequence of the rest of this License.

  8. If the distribution and/or use of the Program is restricted in
certain countries either by patents or by copyrighted interfaces, the
original copyright holder who places the Program under this License
may add an explicit geographical distribution limitation excluding
those countries, so that distribution is permitted only in or among
countries not thus excluded.  In such case, this License incorporates
the limitation as if written in the body of this License.

  9. The Free Software Foundation may publish revised and/or new versions
of the General Public License from time to time.  Such new versions will
be similar in spirit to the present version, but may differ in detail to
address new problems or concerns.

Each version is given a distinguishing version number.  If the Program
specifies a version number of this License which applies to it and "any
later version", you have the option of following the terms and conditions
either of that version or of any later version published by the Free
Software Foundation.  If the Program does not specify a version number of
this License, you may choose any version ever published by the Free Software
Foundation.

  10. If you wish to incorporate parts of the Program into other free
programs whose distribution conditions are different, write to the author
to ask for permission.  For software which is copyrighted by the Free
Software Foundation, write to the Free Software Foundation; we sometimes
make exceptions for this.  Our decision will be guided by the two goals
of preserving the free status of all derivatives of our free software and
of promoting the sharing and reuse of software generally.

                            NO WARRANTY

  11. BECAUSE THE PROGRAM IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE PROGRAM, TO THE EXTENT PERMITTED BY APPLICABLE LAW.  EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE PROGRAM "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED
OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.  THE ENTIRE RISK AS
TO THE QUALITY AND PERFORMANCE OF THE PROGRAM IS WITH YOU.  SHOULD THE
PROGRAM PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL NECESSARY SERVICING,
REPAIR OR CORRECTION.

  12. IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE PROGRAM AS PERMITTED ABOVE, BE LIABLE TO YOU FOR DAMAGES,
INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING
OUT OF THE USE OR INABILITY TO USE THE PROGRAM (INCLUDING BUT NOT LIMITED
TO LOSS OF DATA OR DATA BEING RENDERED INACCURATE OR LOSSES SUSTAINED BY
YOU OR THIRD PARTIES OR A FAILURE OF THE PROGRAM TO OPERATE WITH ANY OTHER
PROGRAMS), EVEN IF SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE
POSSIBILITY OF SUCH DAMAGES.

                     END OF TERMS AND CONDITIONS

            How to Apply These Terms to Your New Programs

  If you develop a new program, and you want it to be of the greatest
possible use to the public, the best way to achieve this is to make it
free software which everyone can redistribute and change under these terms.

  To do so, attach the following notices to the program.  It is safest
to attach them to the start of each source file to most effectively
convey the exclusion of warranty; and each file should have at least
the "copyright" line and a pointer to where the full notice is found.

    <one line to give the program's name and a brief idea of what it does.>
    Copyright (C) <year>  <name of author>

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program; if not, write to the Free Software Foundation, Inc.,
    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

Also add information on how to contact you by electronic and paper mail.

If the program is interactive, make it output a short notice like this
when it starts in an interactive mode:

    Gnomovision version 69, Copyright (C) year name of author
    Gnomovision comes with ABSOLUTELY NO WARRANTY; for details type \`show w'.
    This is free software, and you are welcome to redistribute it
    under certain conditions; type \`show c' for details.

The hypothetical commands \`show w' and \`show c' should show the appropriate
parts of the General Public License.  Of course, the commands you use may
be called something other than \`show w' and \`show c'; they could even be
mouse-clicks or menu items--whatever suits your program.

You should also get your employer (if you work as a programmer) or your
school, if any, to sign a "copyright disclaimer" for the program, if
necessary.  Here is a sample; alter the names:

  Yoyodyne, Inc., hereby disclaims all copyright interest in the program
  \`Gnomovision' (which makes passes at compilers) written by James Hacker.

  <signature of Ty Coon>, 1 April 1989
  Ty Coon, President of Vice

This General Public License does not permit incorporating your program into
proprietary programs.  If your program is a subroutine library, you may
consider it more useful to permit linking proprietary applications with the
library.  If this is what you want to do, use the GNU Lesser General
Public License instead of this License.

EOT

echo 'Create uninstall.php'
touch uninstall.php
cat <<EOT >> uninstall.php
<?php

/**
 * Fired when the plugin is uninstalled.
 *
 * When populating this file, consider the following flow
 * of control:
 *
 * - This method should be static
 * - Check if the \$_REQUEST content actually is the plugin name
 * - Run an admin referrer check to make sure it goes through authentication
 * - Verify the output of $_GET makes sense
 * - Repeat with other user roles. Best directly by using the links/query string parameters.
 * - Repeat things for multisite. Once for a single site in the network, once sitewide.
 *
 * This file may be updated more in future version of the Boilerplate; however, this is the
 * general skeleton and outline for how the file should work.
 *
 * For more information, see the following discussion:
 * https://github.com/tommcfarlin/WordPress-Plugin-Boilerplate/pull/123#issuecomment-28541913
 *
 * @link       ${AUTHOR_URI}
 * @since      1.0.0
 *
 * @package    ${PLUGIN_SLUG}
 */

require_once plugin_dir_path(__FILE__) . 'includes/${PLUGIN_SLUG}Activator.php';

// If uninstall not called from WordPress, then exit.
if (!defined('WP_UNINSTALL_PLUGIN')) {
    exit;
}

EOT

if [ $DATABASE_NEED = 'y' ]; then
	cat <<EOT >> uninstall.php
/**
 * Simple Example for uninstall plugin if we have a tables
 */

global \$wpdb;
delete_option('${PLUGIN_FOLDER}_version');
\$tableFirst = \$wpdb->prefix . ${PLUGIN_SLUG}Activator::TABLE_FIRST;
\$tableSecond = \$wpdb->prefix . ${PLUGIN_SLUG}Activator::TABLE_SECOND;

\$sql = sprintf('DROP TABLE IF EXISTS %s, %s', \$tableFirst, \$tableSecond);

\$wpdb->query(\$sql);

EOT
fi

echo 'Create admin/css/admin.css'
touch admin/css/admin.css
cat <<EOT >> admin/css/admin.css
/**
 * All of the CSS for your admin-specific functionality should be included in this file.
 */

EOT

echo 'Create admin/js/admin.js'
touch admin/js/admin.js
cat <<EOT >> admin/js/admin.js
(function(\$) {
    'use strict';

    /**
     * All of the code for your admin-facing JavaScript source
     * should reside in this file.
     *
     * Note: It has been assumed you will write jQuery code here, so the
     * \$ function reference has been prepared for usage within the scope
     * of this function.
     *
     * This enables you to define handlers, for when the DOM is ready:
     *
     * \$(function() {
     *
     * });
     *
     * When the window is loaded:
     *
     * \$(window).load(function() {
     *
     * });
     *
     * ...and/or other possibilities.
     *
     * Ideally, it is not considered best practise to attach more than a
     * single DOM-ready or window-load handler for a particular page.
     * Although scripts in the WordPress core, Plugins and Themes may be
     * practising this, we should strive to set a better example in our own work.
     */

})(jQuery);

EOT

echo 'Create admin/partials/someCodePart.php'
touch admin/partials/someCodePart.php
cat <<EOT >> admin/partials/someCodePart.php
<?php

/**
 * Provide a admin area view for the plugin
 *
 * This file is used to markup the admin-facing aspects of the plugin.
 *
 * @link ${AUTHOR_URI}
 * @since 1.0.0
 *
 * @package ${PLUGIN_SLUG}
 * @subpackage ${PLUGIN_SLUG}/admin/partials
 */
?>

<!-- This file should primarily consist of HTML with a little bit of PHP. -->

EOT

echo "Create admin/partials/${PLUGIN_SLUG}Admin.php"
touch admin/${PLUGIN_SLUG}Admin.php
cat <<EOT >> admin/${PLUGIN_SLUG}Admin.php
<?php
/**
 * The admin-specific functionality of the plugin.
 *
 * Defines the plugin name, version, and two examples hooks for how to
 * enqueue the admin-specific stylesheet and JavaScript.
 *
 * @package ${PLUGIN_SLUG}
 * @subpackage ${PLUGIN_SLUG}/admin
 * @author ${AUTHOR_NAME} <${AUTHOR_EMAIL}>
 */
class ${PLUGIN_SLUG}Admin
{
    /**
     * The ID of this plugin.
     *
     * @since 1.0.0
     * @access private
     * @var string \$pluginName The ID of this plugin.
     */
    private \$pluginName;

    /**
     * The version of this plugin.
     *
     * @since 1.0.0
     * @access private
     * @var string \$version The current version of this plugin.
     */
    private \$version;

    /**
     * Initialize the class and set its properties.
     *
     * @since 1.0.0
     * @param string \$pluginName The name of this plugin.
     * @param string \$version The version of this plugin.
     */
    public function __construct(\$pluginName, \$version)
    {
        \$this->pluginName = \$pluginName;
        \$this->version = \$version;
    }

    /**
     * Register the stylesheets for the admin area.
     *
     * @since 1.0.0
     */
    public function enqueueStyles()
    {
        /**
         * This function is provided for demonstration purposes only.
         *
         * An instance of this class should be passed to the run() function
         * defined in ${PLUGIN_SLUG}Loader as all of the hooks are defined
         * in that particular class.
         *
         * The ${PLUGIN_SLUG}Loader will then create the relationship
         * between the defined hooks and the functions defined in this
         * class.
         */

        wp_enqueue_style(
            \$this->pluginName,
            plugin_dir_url(__FILE__) . 'css/admin.css',
            [],
            \$this->version,
            'all'
        );
    }

    /**
     * Register the JavaScript for the admin area.
     *
     * @since 1.0.0
     */
    public function enqueueScripts()
    {
        /**
         * This function is provided for demonstration purposes only.
         *
         * An instance of this class should be passed to the run() function
         * defined in ${PLUGIN_SLUG}Loader as all of the hooks are defined
         * in that particular class.
         *
         * The ${PLUGIN_SLUG}Loader will then create the relationship
         * between the defined hooks and the functions defined in this
         * class.
         */

        wp_enqueue_script(
            \$this->pluginName,
            plugin_dir_url(__FILE__) . 'js/admin.js',
            ['jquery'],
            \$this->version,
            false
        );
    }
}

EOT

echo 'Create public/css/public.css'
touch public/css/public.css
cat <<EOT >> public/css/public.css
/**
 * All of the CSS for your public-facing functionality should be included in this file.
 */

EOT

echo 'Create public/js/public.js'
touch public/js/public.js
cat <<EOT >> public/js/public.js
(function(\$) {
    'use strict';

    /**
     * All of the code for your public-facing JavaScript source
     * should reside in this file.
     *
     * Note: It has been assumed you will write jQuery code here, so the
     * \$ function reference has been prepared for usage within the scope
     * of this function.
     *
     * This enables you to define handlers, for when the DOM is ready:
     *
     * \$(function() {
     *
     * });
     *
     * When the window is loaded:
     *
     * \$(window).load(function() {
     *
     * });
     *
     * ...and/or other possibilities.
     *
     * Ideally, it is not considered best practise to attach more than a
     * single DOM-ready or window-load handler for a particular page.
     * Although scripts in the WordPress core, Plugins and Themes may be
     * practising this, we should strive to set a better example in our own work.
     */

})(jQuery);

EOT

echo 'Create public/partials/someCodePart.php'
touch public/partials/someCodePart.php
cat <<EOT >> public/partials/someCodePart.php
<?php

/**
 * Provide a public-facing view for the plugin
 *
 * This file is used to markup the public-facing aspects of the plugin.
 *
 * @link       ${AUTHOR_URI}
 * @since      1.0.0
 *
 * @package    ${PLUGIN_SLUG}
 * @subpackage ${PLUGIN_SLUG}/public/partials
 */
?>

<!-- This file should primarily consist of HTML with a little bit of PHP. -->

EOT

echo "Create public/partials/${PLUGIN_SLUG}Public.php"
touch public/${PLUGIN_SLUG}Public.php
cat <<EOT >> public/${PLUGIN_SLUG}Public.php
<?php
/**
 * The public-facing functionality of the plugin.
 *
 * @link ${AUTHOR_URI}
 * @since 1.0.0
 *
 * @package ${PLUGIN_SLUG}
 * @subpackage ${PLUGIN_SLUG}/public
 */

/**
 * The public-facing functionality of the plugin.
 *
 * Defines the plugin name, version, and two examples hooks for how to
 * enqueue the public-facing stylesheet and JavaScript.
 *
 * @package ${PLUGIN_SLUG}
 * @subpackage ${PLUGIN_SLUG}/public
 * @author ${AUTHOR_NAME} <${AUTHOR_EMAIL}>
 */
class ${PLUGIN_SLUG}Public
{
    /**
     * The ID of this plugin.
     *
     * @since 1.0.0
     * @access private
     * @var string \$pluginName The ID of this plugin.
     */
    private \$pluginName;

    /**
     * The version of this plugin.
     *
     * @since 1.0.0
     * @access private
     * @var string \$version The current version of this plugin.
     */
    private \$version;

    /**
     * Initialize the class and set its properties.
     *
     * @since 1.0.0
     * @param string \$pluginName The name of the plugin.
     * @param string \$version The version of this plugin.
     */
    public function __construct(\$pluginName, \$version)
    {
        \$this->pluginName = \$pluginName;
        \$this->version = \$version;
    }

    /**
     * Register the stylesheets for the public-facing side of the site.
     *
     * @since 1.0.0
     */
    public function enqueueStyles()
    {
        /**
         * This function is provided for demonstration purposes only.
         *
         * An instance of this class should be passed to the run() function
         * defined in ${PLUGIN_SLUG}Loader as all of the hooks are defined
         * in that particular class.
         *
         * The ${PLUGIN_SLUG}Loader will then create the relationship
         * between the defined hooks and the functions defined in this
         * class.
         */

        wp_enqueue_style(
            \$this->pluginName,
            plugin_dir_url(__FILE__) . 'css/public.css',
            [],
            \$this->version,
            'all'
        );
    }

    /**
     * Register the JavaScript for the public-facing side of the site.
     *
     * @since 1.0.0
     */
    public function enqueueScripts()
    {
        /**
         * This function is provided for demonstration purposes only.
         *
         * An instance of this class should be passed to the run() function
         * defined in ${PLUGIN_SLUG}Loader as all of the hooks are defined
         * in that particular class.
         *
         * The ${PLUGIN_SLUG}Loader will then create the relationship
         * between the defined hooks and the functions defined in this
         * class.
         */

        wp_enqueue_script(
            \$this->pluginName,
            plugin_dir_url(__FILE__) . 'js/public.js',
            ['jquery'],
            \$this->version,
            false
        );
    }
}

EOT

echo "Create languages/${PLUGIN_SLUG}.pot"
touch languages/${PLUGIN_SLUG}.pot

echo "Create includes/${PLUGIN_SLUG}.php"
touch includes/${PLUGIN_SLUG}.php
cat <<EOT >> includes/${PLUGIN_SLUG}.php
<?php
/**
 * The core plugin class.
 *
 * This is used to define internationalization, admin-specific hooks, and
 * public-facing site hooks.
 *
 * Also maintains the unique identifier of this plugin as well as the current
 * version of the plugin.
 *
 * @since 1.0.0
 * @package ${PLUGIN_SLUG}
 * @subpackage ${PLUGIN_SLUG}/includes
 * @author ${AUTHOR_NAME} <${AUTHOR_EMAIL}>
 */
class ${PLUGIN_SLUG}
{
    /**
     * The loader that's responsible for maintaining and registering all hooks that power
     * the plugin.
     *
     * @since 1.0.0
     * @access protected
     * @var ${PLUGIN_SLUG}Loader \$loader Maintains and registers all hooks for the plugin.
     */
    protected \$loader;

    /**
     * The unique identifier of this plugin.
     *
     * @since 1.0.0
     * @access protected
     * @var string \$pluginName The string used to uniquely identify this plugin.
     */
    protected \$pluginName;

    /**
     * The current version of the plugin.
     *
     * @since 1.0.0
     * @access protected
     * @var string \$version The current version of the plugin.
     */
    protected \$version;

    /**
     * Define the core functionality of the plugin.
     *
     * Set the plugin name and the plugin version that can be used throughout the plugin.
     * Load the dependencies, define the locale, and set the hooks for the admin area and
     * the public-facing side of the site.
     *
     * @since 1.0.0
     */
    public function __construct()
    {
        if (defined('PLUGIN_NAME_VERSION')) {
            \$this->version = PLUGIN_NAME_VERSION;
        } else {
            \$this->version = '1.0.0';
        }

        \$this->pluginName = '${PLUGIN_SLUG}';

        \$this->loadDependencies();
        \$this->setLocale();
        \$this->defineAdminHooks();
        \$this->definePublicHooks();
    }

    /**
     * Load the required dependencies for this plugin.
     *
     * Include the following files that make up the plugin:
     *
     * - ${PLUGIN_SLUG}Loader. Orchestrates the hooks of the plugin.
     * - ${PLUGIN_SLUG}I18n. Defines internationalization functionality.
     * - ${PLUGIN_SLUG}Admin. Defines all hooks for the admin area.
     * - ${PLUGIN_SLUG}Public. Defines all hooks for the public side of the site.
     *
     * Create an instance of the loader which will be used to register the hooks
     * with WordPress.
     *
     * @since 1.0.0
     * @access private
     */
    private function loadDependencies()
    {
        /**
         * The class responsible for orchestrating the actions and filters of the
         * core plugin.
         */
        require_once plugin_dir_path(dirname(__FILE__)) . 'includes/${PLUGIN_SLUG}Loader.php';

        /**
         * The class responsible for defining internationalization functionality
         * of the plugin.
         */
        require_once plugin_dir_path(dirname(__FILE__)) . 'includes/${PLUGIN_SLUG}I18n.php';

        /**
         * The class responsible for defining all actions that occur in the admin area.
         */
        require_once plugin_dir_path(dirname(__FILE__)) . 'admin/${PLUGIN_SLUG}Admin.php';

        /**
         * The class responsible for defining all actions that occur in the public-facing
         * side of the site.
         */
        require_once plugin_dir_path(dirname(__FILE__)) . 'public/${PLUGIN_SLUG}Public.php';

        \$this->loader = new ${PLUGIN_SLUG}Loader();
    }

    /**
     * Define the locale for this plugin for internationalization.
     *
     * Uses the ${PLUGIN_SLUG}I18n class in order to set the domain and to register the hook
     * with WordPress.
     *
     * @since 1.0.0
     * @access private
     */
    private function setLocale()
    {
        \$plugin_i18n = new ${PLUGIN_SLUG}I18n();
        \$this->loader->addAction('plugins_loaded', \$plugin_i18n, 'loadPluginTextdomain');
    }

    /**
     * Register all of the hooks related to the admin area functionality
     * of the plugin.
     *
     * @since 1.0.0
     * @access private
     */
    private function defineAdminHooks()
    {
        \$pluginAdmin = new ${PLUGIN_SLUG}Admin(\$this->getPluginName(), \$this->getVersion());

        \$this->loader->addAction('admin_enqueue_scripts', \$pluginAdmin, 'enqueueStyles');
        \$this->loader->addAction('admin_enqueue_scripts', \$pluginAdmin, 'enqueueScripts');
    }

    /**
     * Register all of the hooks related to the public-facing functionality
     * of the plugin.
     *
     * @since 1.0.0
     * @access private
     */
    private function definePublicHooks()
    {
        \$pluginPublic = new ${PLUGIN_SLUG}Public(\$this->getPluginName(), \$this->getVersion());

        \$this->loader->addAction('wp_enqueue_scripts', \$pluginPublic, 'enqueueStyles');
        \$this->loader->addAction('wp_enqueue_scripts', \$pluginPublic, 'enqueueScripts');
    }

    /**
     * Run the loader to execute all of the hooks with WordPress.
     *
     * @since 1.0.0
     */
    public function run()
    {
        \$this->loader->run();
    }

    /**
     * The name of the plugin used to uniquely identify it within the context of
     * WordPress and to define internationalization functionality.
     *
     * @since 1.0.0
     * @return string The name of the plugin.
     */
    public function getPluginName()
    {
        return \$this->pluginName;
    }

    /**
     * The reference to the class that orchestrates the hooks with the plugin.
     *
     * @since 1.0.0
     * @return ${PLUGIN_SLUG}Loader Orchestrates the hooks of the plugin.
     */
    public function getLoader()
    {
        return \$this->loader;
    }

    /**
     * Retrieve the version number of the plugin.
     *
     * @since 1.0.0
     * @return string The version number of the plugin.
     */
    public function getVersion()
    {
        return \$this->version;
    }

}

EOT

echo "Create includes/${PLUGIN_SLUG}Activator.php"
touch includes/${PLUGIN_SLUG}Activator.php

if [ $DATABASE_NEED = 'y' ]; then
	cat <<EOT >> includes/${PLUGIN_SLUG}Activator.php
<?php
/**
 * Fired during plugin activation.
 *
 * This class defines all code necessary to run during the plugin's activation.
 *
 * @since 1.0.0
 * @package ${PLUGIN_SLUG}
 * @subpackage ${PLUGIN_SLUG}/includes
 * @author ${AUTHOR_NAME} <${AUTHOR_EMAIL}>
 */
class ${PLUGIN_SLUG}Activator
{
    /**
     * Simple Example for create table
     */

    const TABLE_FIRST = 'test_first_table';
    const TABLE_SECOND = 'test_second_table';

    const DB_VERSION = '1.2';

    /**
     * Short Description. (use period)
     *
     * Long Description.
     *
     * @since 1.0.0
     */
    public static function activate()
    {
        \$installedVersion = get_option("${PLUGIN_FOLDER}_version");

        // If install plugin
        if (!\$installedVersion) {
            self::createFirstTable();
            self::createSecondTable();
        } else { // If update plugin
            switch (\$installedVersion) {
                case '1.0':
                    self::updateTo1Dot1();
                case '1.1':
                    self::updateTo1Dot2();
            }
        }

        update_option('${PLUGIN_FOLDER}_version', self::DB_VERSION);
    }

    /**
     * Create first table
     *
     * @since 1.0.0
     */
    private static function createFirstTable()
    {
        global \$wpdb;

        \$tableName = \$wpdb->prefix . self::TABLE_FIRST;

        if (\$wpdb->get_var("show tables like '\$tableName'") !== \$tableName) {
            \$sql = "CREATE TABLE " . \$tableName . " (
                  id BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT,
                  post_id BIGINT(20) UNSIGNED NOT NULL,
                  text TEXT NOT NULL,
                  hash VARCHAR(32) NOT NULL,
                  PRIMARY KEY(id),
                  INDEX post_id (post_id)
                );";

            require_once(ABSPATH . 'wp-admin/includes/upgrade.php');
            dbDelta(\$sql);
        }
    }

    /**
     * Create first table
     *
     * @since 1.2.0
     */
    private static function createSecondTable()
    {
        global \$wpdb;

        \$tableName = \$wpdb->prefix . self::TABLE_SECOND;

        if (\$wpdb->get_var("show tables like '\$tableName'") !== \$tableName) {
            \$sql = "CREATE TABLE " . \$tableName . " (
                  id BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT,
                  post_id BIGINT(20) UNSIGNED NOT NULL,
                  text TEXT NOT NULL,
                  hash VARCHAR(32) NOT NULL,
                  PRIMARY KEY(id),
                  INDEX post_id (post_id)
                );";

            require_once(ABSPATH . 'wp-admin/includes/upgrade.php');
            dbDelta(\$sql);
        }
    }

    /**
     * Update database version to 1.1
     *
     * @since 1.1.0
     */
    private static function updateTo1Dot1()
    {
        global \$wpdb;

        \$commentTable = \$wpdb->prefix . self::TABLE_FIRST;

        \$sql = "ALTER TABLE " . \$commentTable;
        \$sql .= " ADD context TEXT NOT NULL DEFAULT ''";
        \$wpdb->query(\$sql);
    }

    /**
     * Update database version to 1.2
     *
     * @since 1.2.0
     */
    private static function updateTo1Dot2()
    {
        self::createSecondTable();
    }
}

EOT
else
cat <<EOT >> includes/${PLUGIN_SLUG}Activator.php
<?php
/**
 * Fired during plugin activation.
 *
 * This class defines all code necessary to run during the plugin's activation.
 *
 * @since 1.0.0
 * @package ${PLUGIN_SLUG}
 * @subpackage ${PLUGIN_SLUG}/includes
 * @author ${AUTHOR_NAME} <${AUTHOR_EMAIL}>
 */
class ${PLUGIN_SLUG}Activator
{
    public static function activate()
    {
    }
}

EOT
fi

echo "Create includes/${PLUGIN_SLUG}Deactivator.php"
touch includes/${PLUGIN_SLUG}Deactivator.php
cat <<EOT >> includes/${PLUGIN_SLUG}Deactivator.php
<?php
/**
 * Fired during plugin deactivation.
 *
 * This class defines all code necessary to run during the plugin's deactivation.
 *
 * @since 1.0.0
 * @package ${PLUGIN_SLUG}
 * @subpackage ${PLUGIN_SLUG}/includes
 * @author AuthorName <AuthorEmail@email.com>
 */
class ${PLUGIN_SLUG}Deactivator
{
    /**
     * Short Description. (use period)
     *
     * Long Description.
     *
     * @since 1.0.0
     */
    public static function deactivate()
    {
    }
}

EOT

echo "Create includes/${PLUGIN_SLUG}I18n.php"
touch includes/${PLUGIN_SLUG}I18n.php
cat <<EOT >> includes/${PLUGIN_SLUG}I18n.php
<?php
/**
 * Define the internationalization functionality.
 *
 * Loads and defines the internationalization files for this plugin
 * so that it is ready for translation.
 *
 * @since 1.0.0
 * @package ${PLUGIN_SLUG}
 * @subpackage ${PLUGIN_SLUG}/includes
 * @author AuthorName <AuthorEmail@email.com>
 */
class ${PLUGIN_SLUG}I18n
{
    /**
     * Load the plugin text domain for translation.
     *
     * @since 1.0.0
     */
    public function loadPluginTextdomain()
    {
        load_plugin_textdomain(
            '${PLUGIN_SLUG}',
            false,
            dirname(dirname(plugin_basename(__FILE__))) . '/languages/'
        );
    }
}

EOT

echo "Create includes/${PLUGIN_SLUG}Loader.php"
touch includes/${PLUGIN_SLUG}Loader.php
cat <<EOT >> includes/${PLUGIN_SLUG}Loader.php
<?php
/**
 * Register all actions and filters for the plugin.
 *
 * Maintain a list of all hooks that are registered throughout
 * the plugin, and register them with the WordPress API. Call the
 * run function to execute the list of actions and filters.
 *
 * @package ${PLUGIN_SLUG}
 * @subpackage ${PLUGIN_SLUG}/includes
 * @author AuthorName <AuthorEmail@email.com>
 */
class ${PLUGIN_SLUG}Loader
{
    /**
     * The array of actions registered with WordPress.
     *
     * @since 1.0.0
     * @access protected
     * @var array \$actions The actions registered with WordPress to fire when the plugin loads.
     */
    protected \$actions;

    /**
     * The array of filters registered with WordPress.
     *
     * @since 1.0.0
     * @access protected
     * @var array \$filters The filters registered with WordPress to fire when the plugin loads.
     */
    protected \$filters;

    /**
     * Initialize the collections used to maintain the actions and filters.
     *
     * @since 1.0.0
     */
    public function __construct()
    {
        \$this->actions = array();
        \$this->filters = array();
    }

    /**
     * Add a new action to the collection to be registered with WordPress.
     *
     * @since 1.0.0
     * @param string \$hook The name of the WordPress action that is being registered.
     * @param object \$component A reference to the instance of the object on which the action is defined.
     * @param string \$callback The name of the function definition on the \$component.
     * @param int \$priority Optional. The priority at which the function should be fired. Default is 10.
     * @param int \$acceptedArgs Optional. The number of arguments that should be passed to the \$callback. Default is 1.
     */
    public function addAction(\$hook, \$component, \$callback, \$priority = 10, \$acceptedArgs = 1)
    {
        \$this->actions = \$this->add(\$this->actions, \$hook, \$component, \$callback, \$priority, \$acceptedArgs);
    }

    /**
     * Add a new filter to the collection to be registered with WordPress.
     *
     * @since 1.0.0
     * @param string \$hook The name of the WordPress filter that is being registered.
     * @param object \$component A reference to the instance of the object on which the filter is defined.
     * @param string \$callback The name of the function definition on the \$component.
     * @param int \$priority Optional. The priority at which the function should be fired. Default is 10.
     * @param int \$acceptedArgs Optional. The number of arguments that should be passed to the \$callback. Default is 1
     */
    public function addFilter(\$hook, \$component, \$callback, \$priority = 10, \$acceptedArgs = 1)
    {
        \$this->filters = \$this->add(\$this->filters, \$hook, \$component, \$callback, \$priority, \$acceptedArgs);
    }

    /**
     * A utility function that is used to register the actions and hooks into a single
     * collection.
     *
     * @since 1.0.0
     * @access private
     * @param array \$hooks The collection of hooks that is being registered (that is, actions or filters).
     * @param string \$hook The name of the WordPress filter that is being registered.
     * @param object \$component A reference to the instance of the object on which the filter is defined.
     * @param string \$callback The name of the function definition on the \$component.
     * @param int \$priority The priority at which the function should be fired.
     * @param int \$accepted_args The number of arguments that should be passed to the \$callback.
     * @return array The collection of actions and filters registered with WordPress.
     */
    private function add(\$hooks, \$hook, \$component, \$callback, \$priority, \$accepted_args)
    {
        \$hooks[] = array(
            'hook'          => \$hook,
            'component'     => \$component,
            'callback'      => \$callback,
            'priority'      => \$priority,
            'accepted_args' => \$accepted_args
        );

        return \$hooks;
    }

    /**
     * Register the filters and actions with WordPress.
     *
     * @since 1.0.0
     */
    public function run()
    {
        foreach (\$this->filters as \$hook) {
            add_filter(
                \$hook['hook'],
                [\$hook['component'], \$hook['callback']],
                \$hook['priority'],
                \$hook['accepted_args']
            );
        }

        foreach (\$this->actions as \$hook) {
            add_action(
                \$hook['hook'],
                [\$hook['component'], \$hook['callback']],
                \$hook['priority'],
                \$hook['accepted_args']
            );
        }
    }
}

EOT

printf "${SUCCESS_COLOR}Skeleton successfully created"


printf "\n${NO_COLOR}Developer guidelines: ${LINK_COLOR}https://developer.wordpress.org/plugins/wordpress-org/detailed-plugin-guidelines/"
printf "\n${NO_COLOR}How work README.txt: ${LINK_COLOR}https://developer.wordpress.org/plugins/wordpress-org/how-your-readme-txt-works/"
printf "\n${NO_COLOR}How use subversion in wp repository: ${LINK_COLOR}https://developer.wordpress.org/plugins/wordpress-org/how-to-use-subversion/"
printf "\n${NO_COLOR}How add icon and banner to plugin: ${LINK_COLOR}https://developer.wordpress.org/plugins/wordpress-org/plugin-assets/"
fi

printf "\n"
