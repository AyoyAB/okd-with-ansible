# Local testing using molecule

Test the ansible scripts locally using molecule.  
Molecule uses vagrant and virtualbox to create virtual machines to perform the installation on.

## Dependencies

* Molecule
* Vagrant
* Virtualbox

### Molecule

https://molecule.readthedocs.io/en/latest/

```shell
pip3 install molecule ansible-core
```

### VirtualBox

https://www.virtualbox.org/wiki/Downloads

#### macOS

```shell
brew install --cask virtualbox
```

### Vagrant

https://developer.hashicorp.com/vagrant/downloads

#### macOS

```shell
brew install hashicorp/tap/hashicorp-vagrant
```

```shell
pip3 install 'molecule-plugins[vagrant]'
pip3 install python-vagrant
```

## Usage

### Test

To perform a full test, run:

```shell
molecule test
```

### Manual testing

These are the commands used for testing manually:

```shell
molecule create
molecule converge
molecule verify
molecule destroy
```
