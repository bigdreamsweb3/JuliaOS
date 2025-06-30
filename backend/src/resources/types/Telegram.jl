module Telegram

struct Chat
    id::String
end

function Chat(data::Dict{String, Any})
    return Chat(string(data["id"]))
end
Base.convert(::Type{Chat}, data::Dict{String, Any}) = Chat(data)

struct Message
    chat::Chat
    from::Chat
    text::String
end

function Message(data::Dict{String, Any})
    return Message(
        Chat(data["chat"]),
        Chat(data["from"]),
        data["text"]
    )
end
Base.convert(::Type{Message}, data::Dict{String, Any}) = Message(data)

end
