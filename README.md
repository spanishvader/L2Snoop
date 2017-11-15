# L2Snoop

This script is to help facilitate setting up a system to perform mitm with port redirection. The tool should be used on a linux computer with two ethernet interfaces that can be bridged together. Some mitm setups require the ability to be able to intercept traffic between two "proxy unaware" devices on the same network. In these scenearios setting your computer as the default gateway on the target device will not work if the traffic you are trying to intercept never traverses the gateway. As the packets pass throught the bridge device the packets are kicked from L2 to L3 for iptables to make the redirection.

This script needs to run as root to work. 

    Copyright (C) 2017 Mark Thorson

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published
    by the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.


