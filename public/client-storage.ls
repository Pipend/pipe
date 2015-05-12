delete-document = (key) -> local-storage.remove-item key

get-document = (key) -> 
    json-string = local-storage.get-item key
    if !!json-string then JSON.parse json-string else null

save-document = (key, document) -> local-storage.set-item key, JSON.stringify document 

module.exports = {delete-document, get-document, save-document}