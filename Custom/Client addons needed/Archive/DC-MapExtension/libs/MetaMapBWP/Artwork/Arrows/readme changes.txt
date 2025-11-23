For the sword arrow cpmpass change xml:

Line.7 <AbsDimension x='40' y='40'/>
to <AbsDimension x='128' y='128'/>

Line.29 <AbsDimension x='0' y='-10'/>
to <AbsDimension x='0' y='100'/>

line.40 <AbsDimension x="0" y="15"/>
to <AbsDimension x="0" y="-5"/>

also change frame name="BWP_DisplayFrame" to: strata="LOW" and toplevel="false" to be able to click-through it


Can flip BWPDestText and BWPDistanceText by swaping -5 with 100 and BOTTOM with TOP (x2)