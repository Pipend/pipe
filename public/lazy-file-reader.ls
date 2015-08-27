{each, map, fold, last} = require \prelude-ls
stream = require \stream

# Int -> File -> ReaderStream  
readFile = (chunkSize, file) -->
    totalSize = file.sizes

    closed = false
    read = 0

    callback = null

    fr = new FileReader! 
        ..onload = ->
            if read > totalSize
                callback null
            else
                read := read + chunkSize
                callback @result
   
  
    reader = (_callback) ->
        callback := _callback
        fr.readAsText file.slice read, read + chunkSize
    
    new stream.Readable!
        .._read = ->
            return if closed
            content <~ reader
            @push content
            if !content
                console.log "no more content"
                @emit "end"
                @close!
        ..close = ->
          console.log "file reader closed :)"
          return if closed    
          closed := true

# (String -> {parsed: [String], pending: String }) -> StreamReader -> StreamReader
# consumes the whole stream
splitReader = (splitter, reader) -->
    incompleteLine = ""
    tstream = new stream.Transform!
        .._transform = (chunk, enc, next) ->
            {parsed, pending} = splitter incompleteLine + chunk.toString!
            parsed |> each (p) ~>
                @push p
            incompleteLine := pending
            next!
        .._flush = (next) ->
            @push incompleteLine
            next!
        ..close = ->
            reader.close!
          
    reader.once "end", ->
        tstream.emit "end" 
        
    reader.pipe tstream
    
# Int -> StreamReader String -> StreamRadeadr "[String]"
# consumes the whole stream
bucketizeReader = (n, reader) -->
    incompleteBucket = []
    tstream = new stream.Transform!
        .._transform = (chunk, enc, next) ->
            incompleteBucket.push chunk.toString!
            if incompleteBucket.length == n
                @push <| JSON.stringify incompleteBucket
                incompleteBucket := []
            next!
        .._flush = (next) ->
            <~ reader._flush
            if incompleteBucket.length > 0
                @push <| JSON.stringify incompleteBucket
            next!
        ..close = ->
            reader.close!
            
    reader.once "end", ->
        tstream.emit "end" 
        
    reader.pipe tstream
                
# Int -> StreamReader -> StreamReader
# consumes the whole stream
readNLines = (n, reader) -->
    group = (n) -> fold do
        (acc, a) ->
            latest = last acc
            if !latest or latest.length == n
                latest := []; acc.push latest
            latest.push a
            acc
        []
    
    splitReader do 
        (content) ->
            arr = content.split "\n"
            if arr.length > n
                [...parsed, pending] = arr
                {parsed: (parsed |> group n |> map (.join "\n")), pending}
            else 
                {parsed: [], pending: content}
        reader

# Int -> StreamReader -> StreamReader
# require explicit close even in pipe
readMinNBytes = (n, reader) -->
    total = 0
    tstream = new stream.Transform!
        .._transform = (chunk, enc, next) ->
            if !chunk
                console.log "no chunk"
                @push null
                @emit "end"
                #@close!
            else
                content = chunk.toString!
                total += content.length
                @push content
                if total >= n
                    console.log "total > n", total, n
                    #@push null
                    @emit "end"
                    #@close!
                else
                    next!
    tstream.close = ->
        reader.close!
    reader.pipe tstream
    
# require explicit close even in pipe
readTakeN = (n, reader) -->
    total = 0
    tstream = new stream.Transform!
        .._transform = (chunk, enc, next) ->
            content = chunk.toString!
            @push content
            total += 1
            if total >= n
                @emit "end"
                #@close!
            else
                next!
    tstream.close = ->
        reader.close!
    reader.pipe tstream


module.exports = {
    readFile
    splitReader
    bucketizeReader
    readNLines
    readMinNBytes
    readTakeN
}