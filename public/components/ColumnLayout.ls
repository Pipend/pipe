{create-class, create-factory, DOM:{div, span}}:React = require \react
{create-fragment} = require \react-addons-create-fragment
{map, filter, reject, sum, zip} = require \prelude-ls

# expand :: [Int] -> Int -> Int -> [Int]
expand = (arr, index, amount) ->
    
    # decrement :: [Int] -> Int -> Int -> Int
    decrement = (arr, index, amount) ->
        return 0 if index >= arr.length or amount == 0
        max-dec = arr[index] - min-height
        dec = if amount < max-dec then amount else max-dec
        arr[index] -= dec
        dec + (decrement arr, (index + 1), amount - dec)
        
    arr[index] += decrement arr, (index + 1), amount
    arr
 
# collapse :: [Int] -> Int -> Int -> [Int]
collapse = (arr, index, amount) ->
    
    # decrement :: [Int] -> Int -> Int -> Int
    decrement = (arr, index, amount) ->
        return 0 if index < 0
        max-dec = arr[index] - min-height
        dec = if amount < max-dec then amount else max-dec
        arr[index] -= dec
        dec + (decrement arr, (index - 1), amount - dec)
        
    arr[index + 1] += decrement arr, index, amount
    arr

module.exports = create-class do 

    # get-default-props :: a -> Props
    get-default-props: ->
        # children :: [ReactElement]
        handle-width: 5
        style: {} # CSS inline styles for root node
        # width :: Int
        width-of-each-child: [] # [Int]

    # a -> ReactElement
    render: ->

        children = 
            | typeof! @props.children == \Object => [@props.children]
            | typeof! @props.children == \Array => @props.children
            | _ => []

        total-occupied-width = @props.width-of-each-child
            |> filter -> !!it
            |> sum

        children-without-width = @props.width-of-each-child
            |> reject -> !!it
            |> (.length)

        space-occupied-by-handle = (@props.children.length - 1) * @props.handle-width

        equal-share = (@props.width - space-occupied-by-handle - total-occupied-width) / children-without-width

        # COLUMN LAYOUT
        div do 
            class-name: \column-layout
            style: {} <<< @props.style <<< width: @props.width
            [0 til children.length] `zip` children |> map ([index, child]) ~>
                create-fragment do
                    "left#{index}" : div do 
                        class-name: \component-wrapper
                        style: 
                            width: @props.width-of-each-child[index] ? equal-share
                        child
                    "right#{index}" : div class-name: \resize-handle, style: width: @props.handle-width
                    