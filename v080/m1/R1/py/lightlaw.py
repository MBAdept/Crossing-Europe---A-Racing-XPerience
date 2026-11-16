import math
def to_lin(c): return c*(c*(c*0.305306011+0.682171111)+0.012522878)
def show(x): return max(1.055*max(x,0.0)**0.416666667-0.055,0.0)
def unshow(d): return ((d+0.055)/1.055)**2.4 if d>0 else 0.0
def P(d): return show(to_lin(d))
def Pinv(F):
    lo,hi=0.0,2.0
    for _ in range(60):
        m=(lo+hi)/2
        if P(m)<F: lo=m
        else: hi=m
    return (lo+hi)/2
def final(albedo, A, S=0.0, ndl=1.0):
    a=to_lin(albedo)
    return P(show(a*A)+show(a*S*ndl))
def calib(p, ref, post=True):
    F=ref*p
    d=Pinv(F) if post else F
    return unshow(d)/to_lin(ref)
night=(0.212,0.263,0.373)
day=(1.0,1.0,1.0)
dusk=(0.788,0.584,0.541)
if __name__ == "__main__":
    for name,p in (("night",night),("dusk",dusk),("day",day)):
        for ref in (0.38,0.32,0.28,0.24):
            A=[calib(c,ref) for c in p]
            row=[]
            for alb in (0.12,0.16,0.2,0.25,0.3,0.38,0.45,0.6,0.9):
                worst=[(final(alb,A[i])/(alb*p[i])-1)*100 for i in range(3)]
                row.append("%5.0f/%4.0f/%4.0f"%tuple(worst))
            print(name,"ref",ref,"A=(%.3f %.3f %.3f)"%tuple(A)," ".join(row))
