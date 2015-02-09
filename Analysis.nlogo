extensions [ table csv xw ]

globals [
  header
  full-data
  xw-ycor-reporter
  xw-xcor-reporter
  xw-color-reporter
  xw-size-reporter
  xw-label-reporter
  xw-shape-reporter
  xw-current-offset
]

breed [ points point ]

points-own [
  data
  group-id
]

to startup
  xw:clear-all
  xw:create-tab "data" [
    xw:set-title "Data"
  ]
end

; Change colors to use gradient or discrete (checkbox between them)
; Shape applied to discretized values
to setup
  ca
  set-default-shape points "circle"
  let data-file user-file
  if is-string? data-file [
    let data-table read-csv data-file header-line
    set header first data-table
    set full-data but-first data-table
    let num-points length full-data
    let max-cor num-points - 1
    resize-world 0 max-cor 0 max-cor
    set-patch-size 500 / (max-cor + 1)
    foreach header [
      output-print ?
    ]
    set size-reporter "1"
    set label-reporter "\"\""
    set group-by ""
    
    regroup
  ]
  startup
  setup-xw
  display
end

to setup-xw
  xw:create-button "update-reporters" [
    xw:set-label "Commit"
    xw:set-commands "update-xw-reporters"
  ]
  create-choosers [xw:x + xw:width] xw:of "update-reporters"
  set xw-current-offset 30
  foreach header [
    create-data-manipulation-row ?1 xw-current-offset
    set xw-current-offset xw-current-offset + 30
  ]
end

to create-choosers [x-offset]
  let current-x-offset x-offset
  foreach [["xcor" "X"] ["ycor" "Y"] ["color" "Color"] ["size" "Size"] ["label" "Label"] ["shape" "Shape"]] [
    let key (first ?)
    let lbl (last ?)
    xw:create-chooser key [
      xw:set-label lbl
      xw:set-x current-x-offset + 10
      xw:set-items (fput "default" header)
    ]
    set current-x-offset [xw:x + xw:width] xw:of key
  ]
end
  

to create-data-manipulation-row [name offset]
  xw:create-note (word "label " name) [
    xw:set-y offset
    xw:set-height 30
    xw:set-text name
  ]
  xw:create-chooser (word "chooser " name) [
    xw:set-x [xw:x + xw:width + 10] xw:of (word "label " name)
    xw:set-y offset
    xw:set-height 30
    xw:set-items ["string" "number" "date" "boolean"]
    xw:set-selected-item "string"
  ]
  xw:create-checkbox (word "enumerate " name) [
    xw:set-x [xw:x + xw:width + 10] xw:of (word "chooser " name)
    xw:set-y offset
    xw:set-height 30
    xw:set-label "Enumerate Like"
  ]
end

to update-xw-reporters
  set xw-xcor-reporter updated-reporter "xcor" "1"
  set xw-ycor-reporter updated-reporter "ycor" "1"
  set xw-color-reporter updated-reporter "color" "who"
  set xw-size-reporter updated-reporter "size" "1"
  set xw-label-reporter updated-reporter "label" "\"\"" 
  set xw-shape-reporter updated-reporter "shape" "\"circle\""
end

to-report updated-reporter [selected-axis default-reporter]
  let selection [xw:selected-item] xw:of selected-axis
  ifelse selection != "default" [
    ifelse [xw:selected-item] xw:of (word "chooser " selection) = "number" [
      xw:ask (word "enumerate " selection) [
        xw:set-enabled? false 
        xw:set-selected? false
      ]
      report (word "read-from-string (get \"" selection "\")")
    ] [
    ifelse [xw:selected?] xw:of (word "enumerate " selection) [
      open-enumerate-row selected-axis selection
      report (task [xw:get (word "enumerate value " selection " " (get selection))]) 
    ] [
      report (word "\"" selection "\"")
    ]]
  ] [
  report default-reporter
  ]
end

to open-enumerate-row [selected-axis selection]
  let distinct-values remove-duplicates [get selection] of points
  let choices display-values selected-axis
  ifelse length choices = 2 and is-number? first choices and is-number? last choices [
    let min-choice first choices
    let max-choice last choices
    let x-offset 0
    if not member? (word "enumerate value " selection " " (first distinct-values)) xw:widgets [
      foreach distinct-values [
        xw:create-slider (word "enumerate value " selection " " ?) [
          xw:set-x x-offset
          xw:set-y xw-current-offset + 10
          xw:set-label ?
          xw:set-minimum min-choice
          xw:set-maximum max-choice
          xw:set-value min-choice + max-choice / 2
        ]
        set x-offset x-offset + [xw:width + 10] xw:of (word "enumerate value " selection " " ?) 
      ]
      set xw-current-offset xw-current-offset + 50
    ]
  ] [
  let x-offset 0
  if not member? (word "enumerate value " selection " " (first distinct-values)) xw:widgets [
    foreach distinct-values [
      xw:create-chooser (word "enumerate value " selection " " ?) [
        xw:set-x x-offset
        xw:set-y xw-current-offset + 10
        xw:set-label ?
        xw:set-items choices
        xw:set-selected-item first choices
      ]
      set x-offset x-offset + [xw:width + 10] xw:of (word "enumerate value " selection " " ?)
    ]
    set xw-current-offset xw-current-offset + 50
  ]
  ]
end

to-report display-values [selected-axis]
  if selected-axis = "size" [
    report [0 30]
  ]
  if selected-axis = "shape" [
    report [
      "circle" "default" "airplane" "arrow" "box" "bug" "butterfly" "car"
      "circle 2" "cow" "cylinder" "dot" "face happy" "face neutral"
      "face sad" "fish" "flag" "flower" "house" "leaf" "line"
      "line half" "pentagon" "person" "plant" "sheep" "square" "square 2"
      "star" "target" "tree" "triangle" "triangle 2" "truck" "turtle"
      "wheel" "x"
    ]
  ]
  report [0 100]
end

to regroup
  let do-grouping? group-by != ""
  let group-by-task compile group-by
  clear-turtles
  
  foreach full-data [
    create-points 1 [
      set data ?
      if not empty? filter-by and not runresult filter-by [ die ]
      set data map [ (list ?) ] data
      set color extract-rgb color
      
      ifelse do-grouping? [
        set group-id runresult group-by-task
        
        let group one-of other points with [ group-id = [ group-id ] of myself ]
        if group != nobody [
          let new-data data
          ask group [
            set data (map sentence data new-data)
          ]
          die
        ]
      ] [
        set group-id who
      ]
    ]
  ]
  
  if all? points [ not is-group? ] [
    ask points [ set data map first data ]
  ]
end

to go
  let rate 1
  interpolate-to-normed-value (task [ xcor ]) (task [ set xcor ? ]) xw-xcor-reporter min-pxcor max-pxcor 0.3
  interpolate-to-normed-value (task [ ycor ]) (task [ set ycor ? ]) xw-ycor-reporter min-pycor max-pycor 0.3
  interpolate-to-normed-value (task [ first extract-hsb color ]) (task [ set color hsb ? 125 125 ]) xw-color-reporter 0 255 0.5
  interpolate-to-normed-value (task [ size ]) (task [ set size ? ]) xw-size-reporter (0.5 * size-scale) (2 * size-scale) 0.3
  set-value (task [ shape ]) (task [set shape ?]) xw-shape-reporter
  ask turtles [
    set label runresult label-reporter
  ]
  if mouse-inside? and mouse-down? [
    print ""
    (foreach header [ data ] of min-one-of turtles [ distancexy mouse-xcor mouse-ycor ] [
       print (word ?1 ": " ?2)
    ])
  ]
  display
end

to set-value [getter setter reporter]
  if is-string? reporter [ set reporter compile reporter ]
  let vals [runresult reporter ] of points
  if empty? vals [ set vals [0] ]
  ask points [
    let target-val (runresult reporter)
    let cur-val runresult getter
    if cur-val != target-val [
      (run setter target-val)
    ]
  ]
end

to interpolate-to-normed-value [ getter setter reporter target-min target-max rate ]
  if is-string? reporter [ set reporter compile reporter ]
  let vals [ to-num runresult reporter ] of points
  if empty? vals [ set vals [0] ]
  let min-val min vals
  let max-val max vals
  if min-val = max-val [ set max-val min-val + 1 ]
  let width max-val - min-val
  let target-width target-max - target-min
  ask points [
    let target-val target-width * ((to-num runresult reporter) - min-val) / width + target-min
    let cur-val runresult getter
    if cur-val != target-val [
      let diff target-val - cur-val
      (run setter cur-val + rate * diff)
    ]
  ]
end

to-report get [ var-name ]
  report item (position var-name header) data
end

to-report to-num [ val ]
  if is-number? val [ report val ]
  if val = true [ report 1 ]
  if val = false [ report 0 ]
  if is-string? val [
    ifelse member? val header [
      report to-num get val
    ] [
      report length val
    ]
  ]
  if is-list? val [
    report mean (map to-num val)
  ]
  report 0
end

to-report every? [ pred lst ]
  foreach lst [
    if not (runresult pred ?) [ report false ]
  ]
  report true
end

to-report some? [ pred lst ]
  foreach lst [
    if (runresult pred ?) [ report true ]
  ]
  report false
end

to-report is-group?
  report every? (task is-list?) data and (remove-duplicates map length data) != [1] 
end

to-report read-csv [ path skip-lines ]
  file-close-all
  file-open path
  repeat header-line [ let skip file-read-line ]
  let results (list csv:csv-row-to-strings file-read-line)
  while [ not file-at-end? ] [
    let line file-read-line
    if length line > 0 [
      set results lput csv:csv-row-to-strings line results
    ]
  ]
  file-close
  report results
end

to-report split [ str delim ]
  let index position delim str
  ifelse is-number? index [
    let cell substring str 0 index
    let rest substring str (index + length delim) (length str)
    report fput cell (split rest delim)
  ] [
    report (list str)
  ]
end

to-report compile [ code ]
  report runresult (word "task [ " code " ]")
end

to-report to-hsb [ rgb-color ]
  if is-number? rgb-color [ set rgb-color extract-rgb rgb-color ]
  let r item 0 rgb-color / 255
  let g item 1 rgb-color / 255
  let b item 2 rgb-color / 255
  let v max (list r g b)
  let chroma v - (min (list r g b))
  let h 0
  let s ifelse-value (v = 0) [ 0 ] [ chroma / v ]
  
  if chroma > 0 [
    if v = r [
      set h ((g - b) / chroma) mod 6
    ]
    if v = g [
      set h (b - r) / chroma + 2
    ]
    if v = b [
      set h (r - g) / chroma + 4
    ]
    set h h / 6
  ]
  report map [ precision (? * 255) 3 ] (list h s v)
end

to-report min-x
  report min [ to-num runresult (compile xw-xcor-reporter) ] of points
end

to-report max-x
  report max [ to-num runresult (compile xw-xcor-reporter) ] of points
end

to-report min-y
  report min [ to-num runresult (compile xw-ycor-reporter) ] of points
end

to-report max-y
  report max [ to-num runresult (compile xw-ycor-reporter) ] of points
end
@#$#@#$#@
GRAPHICS-WINDOW
645
10
1649
1035
-1
-1
0.5030181086519114
1
10
1
1
1
0
0
0
1
0
993
0
993
1
1
1
ticks
30.0

BUTTON
16
71
82
104
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

INPUTBOX
16
5
110
65
header-line
0
1
0
Number

OUTPUT
8
127
197
507
10

INPUTBOX
610
610
1120
670
xcor-reporter
read-from-string (get \"Longitude\")
1
0
String (reporter)

INPUTBOX
212
205
527
265
ycor-reporter
read-from-string (get \"Latitude\")
1
0
String (reporter)

BUTTON
114
76
177
109
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

INPUTBOX
212
285
527
345
color-reporter
who
1
0
String (reporter)

INPUTBOX
214
359
526
419
size-reporter
1
1
0
String (reporter)

INPUTBOX
214
474
525
534
label-reporter
\"\"
1
0
String (reporter)

INPUTBOX
205
70
525
149
group-by
NIL
1
0
String (reporter)

BUTTON
268
166
350
199
NIL
regroup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
215
427
525
460
size-scale
size-scale
0
10
5
.1
1
NIL
HORIZONTAL

MONITOR
530
10
610
55
NIL
max-y
3
1
11

MONITOR
535
495
610
540
NIL
min-y
3
1
11

MONITOR
580
585
655
630
NIL
min-x
3
1
11

MONITOR
1040
580
1120
625
NIL
max-x
3
1
11

INPUTBOX
205
10
525
70
filter-by
true
1
0
String (reporter)

BUTTON
20
565
222
598
NIL
export-world user-new-file
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
15
605
182
638
NIL
import-world user-file
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.2-RC3
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
1
@#$#@#$#@
