"""Original articulated 3D ellipsoid mascot; orthographic ray tracing.
No imported raster artwork. Model/rig, normals, lighting and depth are in 3D.
Run with Python + numpy + Pillow. --still renders a review frame only.
"""
from pathlib import Path
import math, sys
import numpy as np
from PIL import Image
OUT=Path('assets/illustrations')
N=320
x,y=np.meshgrid(np.linspace(-1.8,1.8,N),np.linspace(3.25,-.35,N))
origin=np.stack([x,y,np.full_like(x,6)],-1)
ray=np.array([0.,0.,-1.])
BLUE=np.array([.54,.79,.95]); LIGHT=np.array([-.5,.8,1.]); LIGHT/=np.linalg.norm(LIGHT)
def render(action,t):
    objects=[]
    def ball(center,scale,color=BLUE,angle=0):
        c,s=math.cos(angle),math.sin(angle)
        rot=np.array([[c,-s,0],[s,c,0],[0,0,1.]])
        objects.append((np.array(center),np.array(scale),np.array(color),rot))
    # Every clip starts and finishes in exactly the same rest pose.
    ease=math.sin(math.pi*t)**2
    bob=.035*math.sin(t*2*math.pi)*ease
    lean=.10*math.sin(t*2*math.pi)*ease if action=='peek' else 0
    lift=.18*math.sin(t*3*math.pi)**2*ease if action=='bounce' else 0
    look=.07*math.sin(t*2*math.pi)*ease if action=='look' else 0
    sleepy=ease if action=='stretch' else 0
    base=bob+lift
    def b(c,s,col=BLUE,a=0):ball((c[0]+lean,c[1]+base,c[2]),s,col,a)
    # One uninterrupted bean silhouette, no separate head, neck or belly patch.
    b((0,1.35,0),(.83,1.13,.57))
    b((-.38,.36,.43),(.35,.36,.39)); b((.38,.36,.43),(.35,.36,.39))
    for side in [-1,1]:
        center=np.array([side*.79,1.08,.12]); angle=side*.24
        if action=='wave' and side==1:
            center+=ease*np.array([.13,.58,.025]);angle+=ease*(-1.0+.30*math.sin(t*6*math.pi))
        elif action=='bounce':
            center+=ease*np.array([side*.08,.23,0]);angle-=side*ease*.65
        elif action=='peek':
            center+=ease*np.array([-side*.13,.17,.29]);angle+=side*ease*.6
        elif action=='stretch' and side==-1:
            center+=ease*np.array([.58,.32,.49]);angle-=ease*.9
        b(center,(.19,.34,.23),BLUE,angle)
    ink=(.16,.19,.22)
    def front(x,y):return .57*math.sqrt(max(.05,1-(x/.83)**2-((y-1.35)/1.13)**2))+.016
    for side in [-1,1]:
        for u in np.linspace(-1,1,15):
            xx=side*.235+look+u*.063
            yy=1.84+(.065*(1-u*u))*(1-2*sleepy)
            b((xx,yy,front(xx,yy)),(.018,.023,.016),ink)
    mouthY=1.67
    b((look,mouthY,front(look,mouthY)),(.093-.031*sleepy,.060+.032*sleepy,.021),ink)
    b((look+.012,mouthY-.031,front(look,mouthY)+.024),(.047,.023,.011),(.98,.58,.57))
    z=np.full((N,N),np.inf); rgb=np.ones((N,N,3))*np.array([.973,.969,.953])
    # Soft ground contact shadow (analytic ellipse beneath 3D geometry).
    shadow=np.exp(-((x-lean)**2/.6+(y-.08)**2/.018))*.16*(1-lift)
    rgb*=1-shadow[:,:,None]
    for center,scale,col,rot in objects:
        o=((origin-center)@rot)/scale; d=(ray@rot)/scale
        aa=np.dot(d,d); bb=2*np.sum(o*d,axis=-1); cc=np.sum(o*o,axis=-1)-1
        det=bb*bb-4*aa*cc; hit=(-bb-np.sqrt(np.maximum(det,0)))/(2*aa)
        mask=(det>=0)&(hit>0)&(hit<z)
        if not mask.any():continue
        pos=origin+hit[:,:,None]*ray
        normal=(((pos-center)@rot)/(scale*scale))@rot.T
        normal/=np.maximum(np.linalg.norm(normal,axis=-1,keepdims=True),1e-8)
        diff=np.maximum(0,normal@LIGHT); rim=np.maximum(0,normal@np.array([.7,.1,.7]))
        shade=.60+.37*diff+.05*rim
        half=LIGHT+np.array([0,0,1]);half/=np.linalg.norm(half)
        spec=np.maximum(0,normal@half)**18*.055
        pixel=np.clip(col*shade[:,:,None]+spec[:,:,None],0,1)
        rgb[mask]=pixel[mask];z[mask]=hit[mask]
    return Image.fromarray(np.uint8(np.clip(rgb,0,1)*255)).resize((256,256), Image.Resampling.LANCZOS)
OUT.mkdir(parents=True,exist_ok=True)
render('wave',0).save(OUT/'login-3d-still.png')
if '--still' not in sys.argv:
    for action in ['wave','look','bounce','peek','stretch']:
        frames=[render(action,i/47) for i in range(48)]
        frames[0].save(OUT/f'login-3d-{action}.gif',save_all=True,append_images=frames[1:],duration=70,loop=0,optimize=True)
        print(action,flush=True)
