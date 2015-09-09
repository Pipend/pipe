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
            if read >= totalSize
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
        ..close = (d) ->
          console.log "file reader closed :)"
          return if closed    
          closed := true

module.exports = {
    readFile
}