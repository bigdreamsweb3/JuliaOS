module Telegram

struct Chat
    id::String
end

struct Message
    chat::Chat
    from::Chat
    text::String
end

end
