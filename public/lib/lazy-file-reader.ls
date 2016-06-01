{each, map, fold, last} = require \prelude-ls
stream = require \stream

# Int -> File -> ReaderStream  
read-file = (chunk-size, file) -->
    callback = null
    closed = false
    read = 0
    total-size = file.sizes

    file-reader = new FileReader! 
        ..onload = ->
            if read >= total-size
                callback null
            
            else
                read := read + chunk-size
                callback @result
  
    reader = (_callback) ->
        callback := _callback
        file-reader.read-as-text file.slice read, read + chunk-size
    
    new stream.Readable!
        .._read = ->
            if !closed
                content <~ reader
                @push content
                if !content
                    @emit \end
                    @close!

        ..close = (d) ->
            if !closed
                closed := true

module.exports = {read-file}