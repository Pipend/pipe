# get-key :: String -> String -> Int -> String
get-key = (project-id, document-id, version) ->
    "#{document-id}-#{version}"

# delete-document :: String -> String -> Int -> ()
delete-document = (project-id, document-id, version) !-> 
    local-storage.remove-item (get-key project-id, document-id, version)

# get-document :: String -> String -> Int -> object
get-document = (project-id, document-id, version) ->
    json-string = local-storage.get-item (get-key project-id, document-id, version)
    
    if json-string 
        JSON.parse json-string 
    
    else 
        null

# save-document :: String -> String -> Int -> object -> ()
save-document = (project-id, document-id, version, document) !-> 
    local-storage.set-item do 
        get-key project-id, document-id, version
        JSON.stringify document 

module.exports = {save-document, get-document, delete-document}