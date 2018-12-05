# wp_plugin_skeleton_sh
Skeleton for wordpress plugin with PSR2 standarts. It is possible to run with a docker.

## Getting Started

To create skeleton for plugin need run sh script in terminal

```
chmod +x wp_plugin_skeleton.sh
./wp_plugin_skeleton.sh
```

### Prerequisites

If in question about the docker installation you answer yes. After installation, enter the created folder with docker-compose.yml file and execute:

```
sudo docker-compose up
```

After that, the docker will run a basic WordPress site with your plugin. The site will be accessible at the address:

```
http://localhost/
```

The code of the plugin itself will be located in the folder with the name of the plugin

