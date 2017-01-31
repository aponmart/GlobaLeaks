import socket

from twisted.protocols import tls


def listen_tcp_on_sock(reactor, fd, factory):
    return reactor.adoptStreamPort(fd, socket.AF_INET, factory)


def listen_tls_on_sock(reactor, fd, contextFactory, factory):
    tlsFactory = tls.TLSMemoryBIOFactory(contextFactory, False, factory)
    port = listen_tcp_on_sock(reactor, fd, tlsFactory)
    port._type = 'TLS'
    return port


def open_socket_listen(ip, port):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.setblocking(False)
    s.bind((ip, port))
    s.listen(1024)
    return s

def reserve_interface_sockets(iface, mask=0):
    https_sock = open_socket_listen(iface, mask+443)
    http_sock = open_socket_listen(iface, mask+80)

    return {'http': http_sock, 'https': https_sock}

def reserve_port_for_ifaces(ifaces, port):
    socks = []
    failed_binds = [] # (ip_addr, err) pairs
    for ip in ifaces:
        try:
            new_sock = open_socket_listen(ip, port)
            socks.append(new_sock)
        except Exception as err:
            failed_binds.append((ip, err))
    return socks, failed_binds
