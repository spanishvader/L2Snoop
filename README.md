# L2Snoop

This script needs to run as root to work. The tool should be used on a linux computer with two ethernet interfaces that can be bridged together. Some mitm setups require the ability to be able to intercept traffic between two "proxy unaware" devices on the same network. In these scenearios it is not possible to act as the gateway for intercepting since the devices will not traverse the gateway when speaking to each other.

Right now there is only guided mode (-g) which will walk the user through setting up the bridge and port redirecting with a series of questions.
 
