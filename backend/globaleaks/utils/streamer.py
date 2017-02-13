import urlparse

from zope.interface import implements

from twisted.web import http, client, _newclient
from twisted.web.client import Agent
from twisted.internet import reactor, protocol, defer, address
from twisted.web.iweb import IBodyProducer
from twisted.web.server import NOT_DONE_YET


class BodyStreamer(protocol.Protocol):
    def __init__(self, streamfunction, finished):
        self._finished = finished
        self._streamfunction = streamfunction

    def dataReceived(self, data):
        self._streamfunction(data)

    def connectionLost(self, reason):
        self._streamfunction = None
        self._finished.callback(None)
        self._finished = None


class BodyForwarder(object):
    implements(IBodyProducer)

    CHUNK_SIZE = 1024
    length = 0

    deferred = None
    inp_buf = None

    def __init__(self, io_buf, length):
        self.inp_buf = io_buf
        self.length = length
        self.deferred = defer.Deferred()

    def startProducing(self, consumer):
        return self.resumeProducing(consumer)

    def resumeProducing(self, consumer):
        print("resumeProducing()")
        chunk = self.inp_buf.read(self.CHUNK_SIZE)
        consumer.write(chunk)
        # TODO handle longer reads
        self.deferred.callback(None)
        return self.deferred

    def stopProducing(self):
        self.deferred = None
        self.inp_buf.close()


class HTTPStreamProxyRequest(http.Request):
    def __init__(self, *args, **kwargs):
        http.Request.__init__(self, *args, **kwargs)

    def process(self):
        proxy_url = urlparse.urljoin(self.transport.protocol.proxy_url, self.uri)
        print('proxying: %s' % proxy_url)

        hdrs = self.requestHeaders
        hdrs.setRawHeaders('X-Forwarded-For', [self.getClientIP()])
        hdrs.setRawHeaders('X-I-AM', ['Goomba'])

        prod = None
        content_length = self.getHeader('Content-Length')
        if content_length is not None:
            hdrs.removeHeader('Content-Length')
            print('Found: %s' % content_length)
            prod = BodyForwarder(self.content, int(content_length))

        http_agent = Agent(reactor, connectTimeout=2)
        proxy_d = http_agent.request(method=self.method,
                                     uri=proxy_url,
                                     headers=hdrs,
                                     bodyProducer=prod)

        reactor.callLater(15, proxy_d.cancel)
        proxy_d.addCallback(self.proxySuccess)
        proxy_d.addErrback(self.proxyError)

        return NOT_DONE_YET

    def proxySuccess(self, response):
        print("proxySuccess: %s" % response)
        self.unregisterProducer()
        self.responseHeaders = response.headers

        d_forward = defer.Deferred()
        response.deliverBody(BodyStreamer(self.write, d_forward))
        d_forward.addBoth(self.forwardClose)

    def proxyError(self, fail):
        print("proxyErr: %s" % fail)
        # TODO respond with 500
        self.unregisterProducer()
        self.forwardClose()

    def proxyClose(self):
        # TODO ensure that the proxy connection is cleaned up
        pass

    def forwardClose(self):
        print("forwardClose()")
        self.unregisterProducer()
        self.finish()
        print("Cleanly finished")


class HTTPStreamChannel(http.HTTPChannel):
    requestFactory = HTTPStreamProxyRequest

    def __init__(self, proxy_url, *args, **kwargs):
        http.HTTPChannel.__init__(self, *args, **kwargs)

        self.proxy_url = proxy_url
        self.http_agent = Agent(reactor)


class HTTPStreamFactory(http.HTTPFactory):

    def __init__(self, proxy_url, *args, **kwargs):
        http.HTTPFactory.__init__(self, *args, **kwargs)
        self.proxy_url = proxy_url

    def buildProtocol(self, addr):
        proto = HTTPStreamChannel(self.proxy_url)
        return proto