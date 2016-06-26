{filter, map, sort-by, camelize, Obj} = require \prelude-ls
{create-class, create-factory, DOM:{a, div, img, input, span, h3}}:React = require \react
require! \react-router
Link = create-factory react-router.Link


[MBody, MTitle, MHeader, MModal] = do ->
  {Modal}:react-bootstrap = require \react-bootstrap
  map do 
    create-factory 
    [Modal.Body, Modal.Title, Modal.Header, Modal]



module.exports = (props) ->
  # Button null, "HELLO"
  MModal {show: true},
    MHeader null,
      MTitle null, "Please log in"
    MBody null,
      Link do 
          class-name: \big
          to: '/login'
          'Login'

