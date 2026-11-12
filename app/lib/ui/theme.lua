local T={}
function T.colors(appearance,dark,flash)
 local flip=appearance==1 and dark or appearance==2 and not dark or false
 if flash then flip=not flip end
 return flip and 0 or 15,flip and 15 or 0
end
return T
