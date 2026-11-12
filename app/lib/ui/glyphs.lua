local G={}
G.names={'play','pause','check','chevron-left','chevron-right','more','backspace','plus'}
function G.draw(g,name,x,y,size,color)
 local q=size//4;local h=size//2;local o={color=color,line_width=math.max(2,size//10)}
 if name=='play' then g:polygon({x+q,y+q,x+size-q,y+h,x+q,y+size-q},{color=color,fill=true})
 elseif name=='pause' then g:rect(x+q,y+q,math.max(3,size//7),size-2*q,{color=color,fill=true});g:rect(x+size-q-math.max(3,size//7),y+q,math.max(3,size//7),size-2*q,{color=color,fill=true})
 elseif name=='check' then g:line(x+q,y+h,x+h,y+size-q,o);g:line(x+h,y+size-q,x+size-q,y+q,o)
 elseif name=='chevron-left' or name=='chevron-right' then local a=name=='chevron-left' and size-q or q;local b=size-a;g:line(x+a,y+q,x+b,y+h,o);g:line(x+b,y+h,x+a,y+size-q,o)
 elseif name=='more' then for n=1,3 do g:circle(x+n*q,y+h,math.max(2,size//12),{color=color,fill=true}) end
 elseif name=='backspace' then g:polygon({x+q,y+q,x+size-q,y+q,x+size-q,y+size-q,x+q,y+size-q,x,y+h},o);g:line(x+h-q//2,y+h-q//2,x+h+q//2,y+h+q//2,o);g:line(x+h-q//2,y+h+q//2,x+h+q//2,y+h-q//2,o)
 elseif name=='plus' then g:line(x+q,y+h,x+size-q,y+h,o);g:line(x+h,y+q,x+h,y+size-q,o)
 end
end
return G
