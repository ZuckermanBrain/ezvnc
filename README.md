# ezVNC

ezVNC is a bash-based reimplementation of the popular `vncserver` wrapper script for `Xvnc`, which is included with most popular GNU/Linux distributions.
It differs from `vncserver` in the following respects:

 * It supports querying information about VNC sessions that are running on different hosts by means of a hidden directory in a user's home directory that keeps track of state.  This allows you to put home directories on an NFS share used by multiple hosts and be able to determine what VNC sessions are running where without needing to log into each host separately.
 * It outputs a URI that is readily usable by the [Apache Guacamole](https://guacamole.apache.org/) [quickconnect extension](https://guacamole.apache.org/doc/gug/adhoc-connections.html).  This URI includes a random password, which is treated like a token and mimics the [token-based authentication](https://jupyter-notebook.readthedocs.io/en/stable/security.html) used by [Jupyter Notebook](https://jupyter.org/).
 * It attempts to autodetect the GNU/Linux distribution that's being used and the VNC server implementation and tweak settings/`Xvnc` command flags accordingly.
