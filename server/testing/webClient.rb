require 'eventmachine'
require 'faye/websocket'
require 'yaml'
    class WebSocketBase
        def initialize(options)
        end

        def new(options)
        end

        def startConnection(options)
            EM.run {
                @ws = Faye::WebSocket::Client.new('ws://frank-d.info:8080', ['gui-server'])
                @ws.on :open do |event|
                    processOpen(:open, event)
                end
                @ws.on :msg do |event|
                    processMessage(:msg, event)
                end
                @ws.on :close do |event|
                    connectionClosed(:close, event)
                end
            }
        end

        def processOpen(msg, e)
            p YAML.dump(msg)
            p YAML.dump(e)
        end

        def processMessage(msg, e)
            p YAML.dump(msg)
            p YAML.dump(e)
        end

        def connectionClosed(msg, e)
            p YAML.dump(msg)
            p YAML.dump(e)
        end
    end

    class WebSockets < WebSocketBase

    end


p self.methods.inspect
ascw = WebSockets.new({})
ascw.startConnection({})
