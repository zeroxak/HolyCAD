#help_index "Graphics/CAD"

#define HCAD_MAX_TRIS       768
#define HCAD_MAX_SEGS      1536
#define HCAD_MAX_CROSS      384
#define HCAD_MAX_VERTS      1024
#define HCAD_MAX_EDGES      2304

#define HCAD_TYPE_BOX         1
#define HCAD_TYPE_CYLINDER    2
#define HCAD_TYPE_IMPORTED    3

#define HCAD_MODE_MODEL       1
#define HCAD_MODE_SLICE       2

#define HCAD_SELECT_VERTEX    1
#define HCAD_SELECT_EDGE      2
#define HCAD_SELECT_FACE      3

#define HCAD_VIEW_WIRE        1
#define HCAD_VIEW_SHADED      2

#define HCAD_VIEW_LEFT      108
#define HCAD_VIEW_RIGHT     480
#define HCAD_VIEW_TOP        30
#define HCAD_VIEW_BOTTOM    442

#define HCAD_PI 3.141592653589793

class HCadVec
{
  F64 x,y,z;
};

class HCadTri
{
  HCadVec p[3];
};

class HCadSeg
{
  F64 x1,y1,x2,y2;
};

class HCadEdge
{
  I64 v[2];
};

HCadTri cad_tris[HCAD_MAX_TRIS];
HCadSeg cad_segs[HCAD_MAX_SEGS];
HCadVec cad_vertices[HCAD_MAX_VERTS];
HCadEdge cad_edges[HCAD_MAX_EDGES];
I64 cad_tri_v[HCAD_MAX_TRIS][3];
I64 cad_face_order[HCAD_MAX_TRIS];
F64 cad_face_depth[HCAD_MAX_TRIS];
I64 cad_tri_count,cad_seg_count;
I64 cad_vertex_count,cad_edge_count;

I64 cad_type,cad_mode,cad_selected_dim,cad_layer,cad_view_mode;
I64 cad_select_mode,cad_selected;
I64 cad_cylinder_sides;
F64 cad_width,cad_depth,cad_height,cad_radius;
F64 cad_min_x,cad_min_y,cad_min_z;
F64 cad_max_x,cad_max_y,cad_max_z;
F64 cad_layer_height,cad_infill_spacing;
F64 cad_yaw,cad_pitch,cad_zoom;
Bool cad_quit,cad_dragging,cad_drag_moved,cad_prev_lb,cad_show_infill;
Bool cad_show_gizmo;
I64 cad_drag_x,cad_drag_y,cad_drag_start_x,cad_drag_start_y;
U8 cad_name[32],cad_status[96];

U0 CadStatus(U8 *st)
{
  StrCpy(cad_status,st);
}

F64 CadMaxF(F64 a,F64 b)
{
  if (a>b)
    return a;
  return b;
}

F64 CadMinF(F64 a,F64 b)
{
  if (a<b)
    return a;
  return b;
}

F64 CadClampF(F64 v,F64 lo,F64 hi)
{
  if (v<lo)
    return lo;
  if (v>hi)
    return hi;
  return v;
}

U8 *CadSelectName()
{
  if (cad_select_mode==HCAD_SELECT_VERTEX)
    return "VERTEX";
  if (cad_select_mode==HCAD_SELECT_EDGE)
    return "EDGE";
  return "FACE";
}

U8 *CadViewName()
{
  if (cad_view_mode==HCAD_VIEW_WIRE)
    return "WIREFRAME";
  return "SHADED";
}

Bool CadVecSame(HCadVec *a,HCadVec *b)
{
  return Abs(a->x-b->x)<0.00001 &&
         Abs(a->y-b->y)<0.00001 &&
         Abs(a->z-b->z)<0.00001;
}

I64 CadTopologyVertex(HCadVec *p)
{
  I64 i;

  for (i=0;i<cad_vertex_count;i++)
    if (CadVecSame(&cad_vertices[i],p))
      return i;

  if (cad_vertex_count>=HCAD_MAX_VERTS)
    return -1;
  i=cad_vertex_count++;
  cad_vertices[i].x=p->x;
  cad_vertices[i].y=p->y;
  cad_vertices[i].z=p->z;
  return i;
}

U0 CadTopologyEdge(I64 a,I64 b)
{
  I64 i,t;

  if (a<0 || b<0 || a==b)
    return;
  if (b<a) {
    t=a;
    a=b;
    b=t;
  }
  for (i=0;i<cad_edge_count;i++)
    if (cad_edges[i].v[0]==a && cad_edges[i].v[1]==b)
      return;

  if (cad_edge_count>=HCAD_MAX_EDGES)
    return;
  cad_edges[cad_edge_count].v[0]=a;
  cad_edges[cad_edge_count].v[1]=b;
  cad_edge_count++;
}

U0 CadBuildTopology()
{
  I64 i,j;

  cad_vertex_count=0;
  cad_edge_count=0;
  for (i=0;i<cad_tri_count;i++) {
    for (j=0;j<3;j++)
      cad_tri_v[i][j]=CadTopologyVertex(&cad_tris[i].p[j]);
    CadTopologyEdge(cad_tri_v[i][0],cad_tri_v[i][1]);
    CadTopologyEdge(cad_tri_v[i][1],cad_tri_v[i][2]);
    CadTopologyEdge(cad_tri_v[i][2],cad_tri_v[i][0]);
  }
  cad_selected=-1;
}

U0 CadAddTri(F64 x1,F64 y1,F64 z1,
             F64 x2,F64 y2,F64 z2,
             F64 x3,F64 y3,F64 z3)
{
  HCadTri *t;
  if (cad_tri_count>=HCAD_MAX_TRIS)
    return;
  t=&cad_tris[cad_tri_count++];
  t->p[0].x=x1;
  t->p[0].y=y1;
  t->p[0].z=z1;
  t->p[1].x=x2;
  t->p[1].y=y2;
  t->p[1].z=z2;
  t->p[2].x=x3;
  t->p[2].y=y3;
  t->p[2].z=z3;
}

U0 CadBounds()
{
  I64 i,j;
  HCadVec *p;

  if (!cad_tri_count) {
    cad_min_x=cad_min_y=cad_min_z=0;
    cad_max_x=cad_max_y=cad_max_z=0;
    return;
  }

  p=&cad_tris[0].p[0];
  cad_min_x=cad_max_x=p->x;
  cad_min_y=cad_max_y=p->y;
  cad_min_z=cad_max_z=p->z;

  for (i=0;i<cad_tri_count;i++)
    for (j=0;j<3;j++) {
      p=&cad_tris[i].p[j];
      cad_min_x=CadMinF(cad_min_x,p->x);
      cad_min_y=CadMinF(cad_min_y,p->y);
      cad_min_z=CadMinF(cad_min_z,p->z);
      cad_max_x=CadMaxF(cad_max_x,p->x);
      cad_max_y=CadMaxF(cad_max_y,p->y);
      cad_max_z=CadMaxF(cad_max_z,p->z);
    }
}

U0 CadCenterMesh()
{
  I64 i,j;
  F64 cx,cy,dz;

  CadBounds;
  cx=(cad_min_x+cad_max_x)/2.0;
  cy=(cad_min_y+cad_max_y)/2.0;
  dz=cad_min_z;
  for (i=0;i<cad_tri_count;i++)
    for (j=0;j<3;j++) {
      cad_tris[i].p[j].x-=cx;
      cad_tris[i].p[j].y-=cy;
      cad_tris[i].p[j].z-=dz;
    }
  CadBounds;
}

U0 CadBuildBox()
{
  F64 x=cad_width/2.0,y=cad_depth/2.0,z=cad_height;

  cad_tri_count=0;

  CadAddTri(-x,-y,0, x,-y,0, x, y,0);
  CadAddTri(-x,-y,0, x, y,0,-x, y,0);
  CadAddTri(-x,-y,z, x, y,z, x,-y,z);
  CadAddTri(-x,-y,z,-x, y,z, x, y,z);

  CadAddTri(-x,-y,0, x,-y,z, x,-y,0);
  CadAddTri(-x,-y,0,-x,-y,z, x,-y,z);
  CadAddTri( x,-y,0, x,-y,z, x, y,z);
  CadAddTri( x,-y,0, x, y,z, x, y,0);
  CadAddTri( x, y,0, x, y,z,-x, y,z);
  CadAddTri( x, y,0,-x, y,z,-x, y,0);
  CadAddTri(-x, y,0,-x, y,z,-x,-y,z);
  CadAddTri(-x, y,0,-x,-y,z,-x,-y,0);

  CadBounds;
  StrCpy(cad_name,"PARAMETRIC BOX");
  CadStatus("Box rebuilt from dimensions");
}

U0 CadBuildCylinder()
{
  I64 i;
  F64 a1,a2,x1,y1,x2,y2,z=cad_height;

  cad_tri_count=0;
  for (i=0;i<cad_cylinder_sides;i++) {
    a1=2.0*HCAD_PI*i/cad_cylinder_sides;
    a2=2.0*HCAD_PI*(i+1)/cad_cylinder_sides;
    x1=cad_radius*Cos(a1);
    y1=cad_radius*Sin(a1);
    x2=cad_radius*Cos(a2);
    y2=cad_radius*Sin(a2);

    CadAddTri(x1,y1,0,x2,y2,0,x2,y2,z);
    CadAddTri(x1,y1,0,x2,y2,z,x1,y1,z);
    CadAddTri(0,0,0,x2,y2,0,x1,y1,0);
    CadAddTri(0,0,z,x1,y1,z,x2,y2,z);
  }

  CadBounds;
  StrCpy(cad_name,"PARAMETRIC CYLINDER");
  CadStatus("Cylinder rebuilt from dimensions");
}

U0 CadFitView()
{
  F64 sx=cad_max_x-cad_min_x;
  F64 sy=cad_max_y-cad_min_y;
  F64 sz=cad_max_z-cad_min_z;
  F64 d=CadMaxF(sx,CadMaxF(sy,sz));
  if (d<1.0)
    d=1.0;
  cad_zoom=230.0/d;
}

U0 CadRebuild()
{
  if (cad_type==HCAD_TYPE_BOX)
    CadBuildBox;
  else if (cad_type==HCAD_TYPE_CYLINDER)
    CadBuildCylinder;
  CadBuildTopology;
  cad_layer=0;
  CadFitView;
}

Bool CadLoadSTL(U8 *filename)
{
  U8 *buf,*ptr,*vertex;
  HCadVec v[3];
  I64 vi=0;
  F64 x,y,z;

  if (!(buf=FileRead(filename))) {
    CadStatus("Could not open C:/HolyCube.STL");
    return FALSE;
  }

  cad_tri_count=0;
  ptr=buf;
  while (vertex=StrMatch("vertex",ptr)) {
    ptr=StrScan(vertex,"vertex %f %f %f\n",&x,&y,&z);
    v[vi].x=x;
    v[vi].y=y;
    v[vi].z=z;
    if (++vi==3) {
      CadAddTri(v[0].x,v[0].y,v[0].z,
                v[1].x,v[1].y,v[1].z,
                v[2].x,v[2].y,v[2].z);
      vi=0;
      if (cad_tri_count>=HCAD_MAX_TRIS)
        break;
    }
  }
  Free(buf);

  if (!cad_tri_count) {
    CadStatus("No ASCII STL triangles found");
    return FALSE;
  }

  CadCenterMesh;
  CadBuildTopology;
  cad_type=HCAD_TYPE_IMPORTED;
  StrCpy(cad_name,"HOLYCUBE.STL");
  cad_layer=0;
  CadFitView;
  CadStatus("ASCII STL loaded and centered");
  return TRUE;
}

Bool CadEdgeHit(HCadVec *a,HCadVec *b,F64 z,F64 *x,F64 *y)
{
  F64 t;
  if ((a->z<=z && z<b->z) || (b->z<=z && z<a->z)) {
    t=(z-a->z)/(b->z-a->z);
    *x=a->x+t*(b->x-a->x);
    *y=a->y+t*(b->y-a->y);
    return TRUE;
  }
  return FALSE;
}

I64 CadSliceMesh(F64 z)
{
  I64 i,n;
  F64 x[3],y[3];
  HCadTri *t;

  cad_seg_count=0;
  for (i=0;i<cad_tri_count && cad_seg_count<HCAD_MAX_SEGS;i++) {
    t=&cad_tris[i];
    n=0;
    if (CadEdgeHit(&t->p[0],&t->p[1],z,&x[n],&y[n]))
      n++;
    if (CadEdgeHit(&t->p[1],&t->p[2],z,&x[n],&y[n]))
      n++;
    if (n<2 && CadEdgeHit(&t->p[2],&t->p[0],z,&x[n],&y[n]))
      n++;
    if (n==2 && (Abs(x[0]-x[1])>0.0001 || Abs(y[0]-y[1])>0.0001)) {
      cad_segs[cad_seg_count].x1=x[0];
      cad_segs[cad_seg_count].y1=y[0];
      cad_segs[cad_seg_count].x2=x[1];
      cad_segs[cad_seg_count].y2=y[1];
      cad_seg_count++;
    }
  }
  return cad_seg_count;
}

I64 CadLayerCount()
{
  I64 count=Ceil((cad_max_z-cad_min_z)/cad_layer_height);
  if (count<1)
    count=1;
  return count;
}

F64 CadLayerZ()
{
  return cad_min_z+(cad_layer+0.5)*cad_layer_height;
}

U0 CadClampLayer()
{
  I64 count=CadLayerCount;
  if (cad_layer<0)
    cad_layer=0;
  if (cad_layer>=count)
    cad_layer=count-1;
}

I64 CadHorizontalCrossings(F64 y,F64 *xs)
{
  I64 i,n=0,j;
  F64 t,tmp;
  HCadSeg *s;

  for (i=0;i<cad_seg_count && n<HCAD_MAX_CROSS;i++) {
    s=&cad_segs[i];
    if ((s->y1<=y && y<s->y2) || (s->y2<=y && y<s->y1)) {
      t=(y-s->y1)/(s->y2-s->y1);
      xs[n++]=s->x1+t*(s->x2-s->x1);
    }
  }

  for (i=0;i<n;i++)
    for (j=i+1;j<n;j++)
      if (xs[j]<xs[i]) {
        tmp=xs[i];
        xs[i]=xs[j];
        xs[j]=tmp;
      }
  return n;
}

I64 CadVerticalCrossings(F64 x,F64 *ys)
{
  I64 i,n=0,j;
  F64 t,tmp;
  HCadSeg *s;

  for (i=0;i<cad_seg_count && n<HCAD_MAX_CROSS;i++) {
    s=&cad_segs[i];
    if ((s->x1<=x && x<s->x2) || (s->x2<=x && x<s->x1)) {
      t=(x-s->x1)/(s->x2-s->x1);
      ys[n++]=s->y1+t*(s->y2-s->y1);
    }
  }

  for (i=0;i<n;i++)
    for (j=i+1;j<n;j++)
      if (ys[j]<ys[i]) {
        tmp=ys[i];
        ys[i]=ys[j];
        ys[j]=tmp;
      }
  return n;
}

U0 CadProject(HCadVec *p,I64 *sx,I64 *sy,F64 *depth)
{
  F64 cy=Cos(cad_yaw),ss=Sin(cad_yaw);
  F64 cp=Cos(cad_pitch),sp=Sin(cad_pitch);
  F64 x1=p->x*cy-p->y*ss;
  F64 y1=p->x*ss+p->y*cy;
  F64 y2=y1*cp-p->z*sp;

  *depth=y1*sp+p->z*cp;
  *sx=(HCAD_VIEW_LEFT+HCAD_VIEW_RIGHT)/2+x1*cad_zoom;
  *sy=(HCAD_VIEW_TOP+HCAD_VIEW_BOTTOM)/2-y2*cad_zoom;
}

U0 CadDrawProjectedLine(CDC *dc,HCadVec *a,HCadVec *b)
{
  I64 x1,y1,x2,y2;
  F64 z1,z2;
  CadProject(a,&x1,&y1,&z1);
  CadProject(b,&x2,&y2,&z2);
  GrLine(dc,x1,y1,x2,y2);
}

U0 CadDrawModelGrid(CDC *dc)
{
  I64 i;
  HCadVec a,b;

  dc->thick=1;
  dc->color=DKGRAY;
  for (i=-100;i<=100;i+=10) {
    a.x=-100;
    a.y=i;
    a.z=0;
    b.x=100;
    b.y=i;
    b.z=0;
    CadDrawProjectedLine(dc,&a,&b);
    a.x=i;
    a.y=-100;
    b.x=i;
    b.y=100;
    CadDrawProjectedLine(dc,&a,&b);
  }

  dc->thick=2;
  a.x=a.y=a.z=0;
  b.x=40;
  b.y=b.z=0;
  dc->color=LTRED;
  CadDrawProjectedLine(dc,&a,&b);
  b.x=0;
  b.y=40;
  dc->color=LTGREEN;
  CadDrawProjectedLine(dc,&a,&b);
  b.y=0;
  b.z=40;
  dc->color=LTBLUE;
  CadDrawProjectedLine(dc,&a,&b);
}

F64 CadTriDepth(HCadTri *t)
{
  I64 x,y,j;
  F64 z,total=0;

  for (j=0;j<3;j++) {
    CadProject(&t->p[j],&x,&y,&z);
    total+=z;
  }
  return total/3.0;
}

I64 CadTriShade(HCadTri *t)
{
  F64 ax=t->p[1].x-t->p[0].x;
  F64 ay=t->p[1].y-t->p[0].y;
  F64 az=t->p[1].z-t->p[0].z;
  F64 bx=t->p[2].x-t->p[0].x;
  F64 by=t->p[2].y-t->p[0].y;
  F64 bz=t->p[2].z-t->p[0].z;
  F64 nx=ay*bz-az*by;
  F64 ny=az*bx-ax*bz;
  F64 nz=ax*by-ay*bx;
  F64 d=Sqrt(nx*nx+ny*ny+nz*nz),light;

  if (d<0.00001)
    return DKGRAY;
  light=Abs((-0.30*nx-0.40*ny+0.85*nz)/d);
  if (light>0.72)
    return WHITE;
  if (light>0.35)
    return LTGRAY;
  return DKGRAY;
}

U0 CadFillTri(CDC *dc,HCadTri *t,I64 color)
{
  I64 j,x,y;
  F64 z;
  CD3I32 poly[3];

  for (j=0;j<3;j++) {
    CadProject(&t->p[j],&x,&y,&z);
    poly[j].x=x;
    poly[j].y=y;
    poly[j].z=0;
  }
  dc->color=color;
  GrFillPoly3(dc,3,poly);
}

U0 CadDrawWire(CDC *dc,I64 color=LTGRAY)
{
  I64 i;
  HCadTri *t;

  dc->thick=1;
  dc->color=color;
  for (i=0;i<cad_tri_count;i++) {
    t=&cad_tris[i];
    CadDrawProjectedLine(dc,&t->p[0],&t->p[1]);
    CadDrawProjectedLine(dc,&t->p[1],&t->p[2]);
    CadDrawProjectedLine(dc,&t->p[2],&t->p[0]);
  }
}

U0 CadDrawShaded(CDC *dc)
{
  I64 i,j,t;
  F64 d;
  HCadTri *tri;

  for (i=0;i<cad_tri_count;i++) {
    cad_face_order[i]=i;
    cad_face_depth[i]=CadTriDepth(&cad_tris[i]);
  }

  for (i=1;i<cad_tri_count;i++) {
    t=cad_face_order[i];
    d=cad_face_depth[t];
    j=i-1;
    while (j>=0 && cad_face_depth[cad_face_order[j]]>d) {
      cad_face_order[j+1]=cad_face_order[j];
      j--;
    }
    cad_face_order[j+1]=t;
  }

  for (i=0;i<cad_tri_count;i++) {
    tri=&cad_tris[cad_face_order[i]];
    CadFillTri(dc,tri,CadTriShade(tri));
  }
  CadDrawWire(dc,BLACK);
}

Bool CadSelectionCenter(HCadVec *p)
{
  I64 a,b;
  HCadTri *t;

  if (cad_selected<0)
    return FALSE;
  if (cad_select_mode==HCAD_SELECT_VERTEX) {
    if (cad_selected>=cad_vertex_count)
      return FALSE;
    p->x=cad_vertices[cad_selected].x;
    p->y=cad_vertices[cad_selected].y;
    p->z=cad_vertices[cad_selected].z;
  } else if (cad_select_mode==HCAD_SELECT_EDGE) {
    if (cad_selected>=cad_edge_count)
      return FALSE;
    a=cad_edges[cad_selected].v[0];
    b=cad_edges[cad_selected].v[1];
    p->x=(cad_vertices[a].x+cad_vertices[b].x)/2.0;
    p->y=(cad_vertices[a].y+cad_vertices[b].y)/2.0;
    p->z=(cad_vertices[a].z+cad_vertices[b].z)/2.0;
  } else {
    if (cad_selected>=cad_tri_count)
      return FALSE;
    t=&cad_tris[cad_selected];
    p->x=(t->p[0].x+t->p[1].x+t->p[2].x)/3.0;
    p->y=(t->p[0].y+t->p[1].y+t->p[2].y)/3.0;
    p->z=(t->p[0].z+t->p[1].z+t->p[2].z)/3.0;
  }
  return TRUE;
}

U0 CadDrawSelectionCandidates(CDC *dc)
{
  I64 i,x,y,a,b;
  F64 z;

  if (cad_select_mode==HCAD_SELECT_VERTEX) {
    dc->color=LTCYAN;
    for (i=0;i<cad_vertex_count;i++) {
      CadProject(&cad_vertices[i],&x,&y,&z);
      GrRect(dc,x-1,y-1,3,3);
    }
  } else if (cad_select_mode==HCAD_SELECT_EDGE) {
    dc->color=LTBLUE;
    dc->thick=1;
    for (i=0;i<cad_edge_count;i++) {
      a=cad_edges[i].v[0];
      b=cad_edges[i].v[1];
      CadDrawProjectedLine(dc,&cad_vertices[a],&cad_vertices[b]);
    }
  }
}

U0 CadDrawSelection(CDC *dc)
{
  I64 x,y,x2,y2,a,b,j;
  F64 z,z2;
  HCadTri *t;
  HCadVec *p1,*p2;

  if (cad_selected<0)
    return;

  dc->color=YELLOW;
  dc->thick=3;
  if (cad_select_mode==HCAD_SELECT_VERTEX &&
      cad_selected<cad_vertex_count) {
    CadProject(&cad_vertices[cad_selected],&x,&y,&z);
    GrRect(dc,x-4,y-4,9,9);
    dc->color=WHITE;
    GrLine(dc,x-7,y,x+7,y);
    GrLine(dc,x,y-7,x,y+7);
  } else if (cad_select_mode==HCAD_SELECT_EDGE &&
             cad_selected<cad_edge_count) {
    a=cad_edges[cad_selected].v[0];
    b=cad_edges[cad_selected].v[1];
    p1=&cad_vertices[a];
    p2=&cad_vertices[b];
    CadDrawProjectedLine(dc,p1,p2);
    CadProject(p1,&x,&y,&z);
    CadProject(p2,&x2,&y2,&z2);
    GrRect(dc,x-3,y-3,7,7);
    GrRect(dc,x2-3,y2-3,7,7);
  } else if (cad_select_mode==HCAD_SELECT_FACE &&
             cad_selected<cad_tri_count) {
    t=&cad_tris[cad_selected];
    if (cad_view_mode==HCAD_VIEW_SHADED)
      CadFillTri(dc,t,LTRED);
    dc->color=YELLOW;
    dc->thick=3;
    for (j=0;j<3;j++)
      CadDrawProjectedLine(dc,&t->p[j],&t->p[(j+1)%3]);
  }
}

U0 CadDrawGizmo(CDC *dc)
{
  I64 x,y,x2,y2,axis;
  F64 z,z2,len;
  HCadVec p,e;

  if (!cad_show_gizmo || !CadSelectionCenter(&p))
    return;

  len=30.0/cad_zoom;
  CadProject(&p,&x,&y,&z);
  for (axis=0;axis<3;axis++) {
    e.x=p.x;
    e.y=p.y;
    e.z=p.z;
    if (axis==0)
      e.x+=len;
    else if (axis==1)
      e.y+=len;
    else
      e.z+=len;
    CadProject(&e,&x2,&y2,&z2);

    if (axis==0)
      dc->color=LTRED;
    else if (axis==1)
      dc->color=LTGREEN;
    else
      dc->color=LTBLUE;
    if (axis==cad_selected_dim)
      dc->thick=4;
    else
      dc->thick=2;
    GrLine(dc,x,y,x2,y2);
    GrRect(dc,x2-3,y2-3,7,7);
    dc->color=WHITE;
    GrPrint(dc,x2+4,y2-4,"%c",'X'+axis);
  }
}

U0 CadDrawMesh(CDC *dc)
{
  if (cad_view_mode==HCAD_VIEW_SHADED)
    CadDrawShaded(dc);
  else
    CadDrawWire(dc);
  CadDrawSelectionCandidates(dc);
  CadDrawSelection(dc);
  CadDrawGizmo(dc);
}

U0 CadDrawSlice(CDC *dc)
{
  I64 i,j,n,cx=(HCAD_VIEW_LEFT+HCAD_VIEW_RIGHT)/2;
  I64 cy=(HCAD_VIEW_TOP+HCAD_VIEW_BOTTOM)/2;
  F64 scale=1.45,z=CadLayerZ,x,y;
  F64 cross[HCAD_MAX_CROSS];

  CadSliceMesh(z);

  dc->color=BLACK;
  GrRect(dc,HCAD_VIEW_LEFT,HCAD_VIEW_TOP,
    HCAD_VIEW_RIGHT-HCAD_VIEW_LEFT,HCAD_VIEW_BOTTOM-HCAD_VIEW_TOP);

  dc->color=DKGRAY;
  for (i=-100;i<=100;i+=20) {
    GrLine(dc,cx-100*scale,cy+i*scale,cx+100*scale,cy+i*scale);
    GrLine(dc,cx+i*scale,cy-100*scale,cx+i*scale,cy+100*scale);
  }

  dc->color=LTGRAY;
  dc->thick=2;
  GrLine(dc,cx-100*scale,cy-100*scale,cx+100*scale,cy-100*scale);
  GrLine(dc,cx+100*scale,cy-100*scale,cx+100*scale,cy+100*scale);
  GrLine(dc,cx+100*scale,cy+100*scale,cx-100*scale,cy+100*scale);
  GrLine(dc,cx-100*scale,cy+100*scale,cx-100*scale,cy-100*scale);

  if (cad_show_infill) {
    dc->color=LTCYAN;
    dc->thick=1;
    if (cad_layer&1) {
      for (x=cad_min_x;x<=cad_max_x;x+=cad_infill_spacing) {
        n=CadVerticalCrossings(x,cross);
        for (j=0;j+1<n;j+=2)
          GrLine(dc,cx+x*scale,cy-cross[j]*scale,
            cx+x*scale,cy-cross[j+1]*scale);
      }
    } else {
      for (y=cad_min_y;y<=cad_max_y;y+=cad_infill_spacing) {
        n=CadHorizontalCrossings(y,cross);
        for (j=0;j+1<n;j+=2)
          GrLine(dc,cx+cross[j]*scale,cy-y*scale,
            cx+cross[j+1]*scale,cy-y*scale);
      }
    }
  }

  dc->color=YELLOW;
  dc->thick=2;
  for (i=0;i<cad_seg_count;i++)
    GrLine(dc,cx+cad_segs[i].x1*scale,cy-cad_segs[i].y1*scale,
      cx+cad_segs[i].x2*scale,cy-cad_segs[i].y2*scale);
}

U0 CadButton(CDC *dc,I64 x,I64 y,I64 w,I64 h,U8 *label,Bool active=FALSE)
{
  if (active)
    dc->color=LTBLUE;
  else
    dc->color=DKGRAY;
  GrRect(dc,x,y,w,h);
  dc->color=WHITE;
  GrPrint(dc,x+7,y+(h-FONT_HEIGHT)/2,"%s",label);
}

U0 CadDrawPanels(CTask *task,CDC *dc)
{
  I64 layers=CadLayerCount;
  F64 sx=cad_max_x-cad_min_x;
  F64 sy=cad_max_y-cad_min_y;
  F64 sz=cad_max_z-cad_min_z;

  dc->thick=1;

  dc->color=BLUE;
  GrRect(dc,0,0,task->pix_width,28);
  dc->color=WHITE;
  GrPrint(dc,10,6,"HOLYCAD");
  dc->color=LTGRAY;
  GrPrint(dc,102,6,"PROJECT   MESH   SELECT   SOLID   SLICE");
  dc->color=YELLOW;
  GrPrint(dc,task->pix_width-FONT_WIDTH*8-8,6,"V0.2 CAD");

  dc->color=LTGRAY;
  GrRect(dc,0,28,106,task->pix_height-56);
  dc->color=BLACK;
  GrPrint(dc,9,35,"CREATE");
  CadButton(dc,8,51,90,21,"1  BOX",cad_type==HCAD_TYPE_BOX);
  CadButton(dc,8,76,90,21,"2  CYLINDER",cad_type==HCAD_TYPE_CYLINDER);
  CadButton(dc,8,101,90,21,"O  OPEN STL",cad_type==HCAD_TYPE_IMPORTED);

  dc->color=BLACK;
  GrPrint(dc,9,130,"SELECT");
  CadButton(dc,8,146,90,21,"Q  VERTEX",
    cad_select_mode==HCAD_SELECT_VERTEX);
  CadButton(dc,8,171,90,21,"E  EDGE",
    cad_select_mode==HCAD_SELECT_EDGE);
  CadButton(dc,8,196,90,21,"F  FACE",
    cad_select_mode==HCAD_SELECT_FACE);

  dc->color=BLACK;
  GrPrint(dc,9,225,"WORKSPACE");
  CadButton(dc,8,241,90,21,"V  MODEL",cad_mode==HCAD_MODE_MODEL);
  CadButton(dc,8,266,90,21,"L  SLICE",cad_mode==HCAD_MODE_SLICE);
  if (cad_view_mode==HCAD_VIEW_WIRE)
    CadButton(dc,8,291,90,21,"M  WIRE",TRUE);
  else
    CadButton(dc,8,291,90,21,"M  SHADED",TRUE);
  CadButton(dc,8,316,90,21,"G  GIZMO",cad_show_gizmo);

  dc->color=BLACK;
  GrPrint(dc,9,345,"OUTPUT");
  CadButton(dc,8,361,90,21,"P  G-CODE");
  CadButton(dc,8,386,90,21,"I  INFILL",cad_show_infill);

  dc->color=DKGRAY;
  GrPrint(dc,9,414,"%d TRI  %d VTX",cad_tri_count,cad_vertex_count);
  GrPrint(dc,9,430,"ESC EXIT");

  dc->color=LTGRAY;
  GrRect(dc,482,28,task->pix_width-482,task->pix_height-56);
  dc->color=BLACK;
  GrPrint(dc,491,38,"INSPECTOR");
  dc->color=DKGRAY;
  GrPrint(dc,491,55,"%s",cad_name);

  dc->color=BLACK;
  GrPrint(dc,491,78,"MESH");
  dc->color=DKGRAY;
  GrPrint(dc,491,95,"%d VERT  %d EDGE",cad_vertex_count,cad_edge_count);
  GrPrint(dc,491,111,"%d FACE",cad_tri_count);
  GrPrint(dc,491,127,"SELECT  %s",CadSelectName);
  if (cad_selected<0)
    GrPrint(dc,491,143,"ACTIVE  NONE");
  else
    GrPrint(dc,491,143,"ACTIVE  %d",cad_selected+1);

  dc->color=BLACK;
  GrPrint(dc,491,169,"TRANSFORM");
  if (cad_selected_dim==0)
    dc->color=YELLOW;
  else
    dc->color=DKGRAY;
  GrPrint(dc,491,186,"X %6.2f",sx);
  if (cad_selected_dim==1)
    dc->color=YELLOW;
  else
    dc->color=DKGRAY;
  GrPrint(dc,491,202,"Y %6.2f",sy);
  if (cad_selected_dim==2)
    dc->color=YELLOW;
  else
    dc->color=DKGRAY;
  GrPrint(dc,491,218,"Z %6.2f MM",sz);

  dc->color=BLACK;
  GrPrint(dc,491,244,"VIEW");
  dc->color=DKGRAY;
  GrPrint(dc,491,261,"A/D YAW  W/S PITCH");
  GrPrint(dc,491,277,"DRAG ORBIT  CLICK PICK");
  GrPrint(dc,491,293,"+/- ZOOM  R FIT");
  GrPrint(dc,491,309,"M %s",CadViewName);
  GrPrint(dc,491,325,"G GIZMO  X/Y/Z AXIS");
  if (cad_selected<0)
    GrPrint(dc,491,341,"[,] RESIZE OBJECT");
  else
    GrPrint(dc,491,341,"[,] MOVE SELECTION");

  dc->color=BLACK;
  GrPrint(dc,491,367,"SLICER");
  dc->color=DKGRAY;
  GrPrint(dc,491,384,"LAYER %d/%d  H %.2f",cad_layer+1,layers,
    cad_layer_height);
  GrPrint(dc,491,400,"INFILL %.1f  SEG %d",cad_infill_spacing,
    cad_seg_count);
  GrPrint(dc,491,416,"</> LAYER  I INFILL");

  dc->color=DKGRAY;
  GrRect(dc,0,task->pix_height-28,task->pix_width,28);
  dc->color=WHITE;
  GrPrint(dc,8,task->pix_height-20,"%s",cad_status);
  dc->color=LTCYAN;
  GrPrint(dc,task->pix_width-FONT_WIDTH*20-8,task->pix_height-20,
    "MM | ORTHO | %s",CadViewName);
}

U0 HolyCADDraw(CTask *task,CDC *dc)
{
  dc->color=BLACK;
  GrRect(dc,HCAD_VIEW_LEFT,HCAD_VIEW_TOP,
    HCAD_VIEW_RIGHT-HCAD_VIEW_LEFT,HCAD_VIEW_BOTTOM-HCAD_VIEW_TOP);

  if (cad_mode==HCAD_MODE_MODEL) {
    CadDrawModelGrid(dc);
    CadDrawMesh(dc);
  } else
    CadDrawSlice(dc);

  CadDrawPanels(task,dc);
}

U0 CadSelectBox()
{
  cad_type=HCAD_TYPE_BOX;
  cad_width=40;
  cad_depth=30;
  cad_height=20;
  cad_selected_dim=0;
  CadRebuild;
}

U0 CadSelectCylinder()
{
  cad_type=HCAD_TYPE_CYLINDER;
  cad_radius=18;
  cad_height=30;
  cad_cylinder_sides=32;
  cad_selected_dim=0;
  CadRebuild;
}

U0 CadSelectMode(I64 mode)
{
  cad_select_mode=mode;
  cad_selected=-1;
  StrPrint(cad_status,"%s selection - click to select, drag to orbit",
    CadSelectName);
}

U0 CadCycleView()
{
  if (cad_view_mode==HCAD_VIEW_WIRE)
    cad_view_mode=HCAD_VIEW_SHADED;
  else
    cad_view_mode=HCAD_VIEW_WIRE;
  StrPrint(cad_status,"%s viewport",CadViewName);
}

F64 CadPointSegDist2(F64 px,F64 py,F64 ax,F64 ay,F64 bx,F64 by)
{
  F64 dx=bx-ax,dy=by-ay,t,x,y;
  F64 len2=dx*dx+dy*dy;

  if (len2<0.00001) {
    dx=px-ax;
    dy=py-ay;
    return dx*dx+dy*dy;
  }
  t=((px-ax)*dx+(py-ay)*dy)/len2;
  t=CadClampF(t,0,1);
  x=ax+t*dx;
  y=ay+t*dy;
  dx=px-x;
  dy=py-y;
  return dx*dx+dy*dy;
}

F64 CadTriSign(F64 px,F64 py,F64 ax,F64 ay,F64 bx,F64 by)
{
  return (px-bx)*(ay-by)-(ax-bx)*(py-by);
}

Bool CadPointInTri(F64 px,F64 py,
                   F64 x1,F64 y1,F64 x2,F64 y2,F64 x3,F64 y3)
{
  F64 d1=CadTriSign(px,py,x1,y1,x2,y2);
  F64 d2=CadTriSign(px,py,x2,y2,x3,y3);
  F64 d3=CadTriSign(px,py,x3,y3,x1,y1);
  Bool neg=d1<0 || d2<0 || d3<0;
  Bool pos=d1>0 || d2>0 || d3>0;
  return !(neg && pos);
}

U0 CadPick(I64 px,I64 py)
{
  I64 i,a,b,x1,y1,x2,y2,x3,y3,best=-1;
  F64 z1,z2,z3,d,best_d=1.0e30,best_z=-1.0e30;
  HCadTri *t;

  if (cad_select_mode==HCAD_SELECT_VERTEX) {
    for (i=0;i<cad_vertex_count;i++) {
      CadProject(&cad_vertices[i],&x1,&y1,&z1);
      d=(px-x1)*(px-x1)+(py-y1)*(py-y1);
      if (d<=121 && (d<best_d || d==best_d && z1>best_z)) {
        best=i;
        best_d=d;
        best_z=z1;
      }
    }
  } else if (cad_select_mode==HCAD_SELECT_EDGE) {
    for (i=0;i<cad_edge_count;i++) {
      a=cad_edges[i].v[0];
      b=cad_edges[i].v[1];
      CadProject(&cad_vertices[a],&x1,&y1,&z1);
      CadProject(&cad_vertices[b],&x2,&y2,&z2);
      d=CadPointSegDist2(px,py,x1,y1,x2,y2);
      if (d<=64 && (d<best_d ||
          d==best_d && (z1+z2)/2.0>best_z)) {
        best=i;
        best_d=d;
        best_z=(z1+z2)/2.0;
      }
    }
  } else {
    for (i=0;i<cad_tri_count;i++) {
      t=&cad_tris[i];
      CadProject(&t->p[0],&x1,&y1,&z1);
      CadProject(&t->p[1],&x2,&y2,&z2);
      CadProject(&t->p[2],&x3,&y3,&z3);
      if (CadPointInTri(px,py,x1,y1,x2,y2,x3,y3) &&
          (z1+z2+z3)/3.0>best_z) {
        best=i;
        best_z=(z1+z2+z3)/3.0;
      }
    }
  }

  cad_selected=best;
  if (best<0)
    CadStatus("Nothing under cursor - selection cleared");
  else
    StrPrint(cad_status,"%s %d selected",CadSelectName,best+1);
}

U0 CadSyncTopologyToMesh()
{
  I64 i,j,v;

  for (i=0;i<cad_tri_count;i++)
    for (j=0;j<3;j++) {
      v=cad_tri_v[i][j];
      if (0<=v<cad_vertex_count) {
        cad_tris[i].p[j].x=cad_vertices[v].x;
        cad_tris[i].p[j].y=cad_vertices[v].y;
        cad_tris[i].p[j].z=cad_vertices[v].z;
      }
    }
}

U0 CadMoveSelection(F64 amount)
{
  Bool moved[HCAD_MAX_VERTS];
  I64 i,j,a,b;

  if (cad_selected<0) {
    CadStatus("Select a component before moving it");
    return;
  }

  MemSet(moved,0,sizeof(moved));
  if (cad_select_mode==HCAD_SELECT_VERTEX &&
      cad_selected<cad_vertex_count)
    moved[cad_selected]=TRUE;
  else if (cad_select_mode==HCAD_SELECT_EDGE &&
           cad_selected<cad_edge_count) {
    a=cad_edges[cad_selected].v[0];
    b=cad_edges[cad_selected].v[1];
    moved[a]=moved[b]=TRUE;
  } else if (cad_select_mode==HCAD_SELECT_FACE &&
             cad_selected<cad_tri_count)
    for (j=0;j<3;j++)
      moved[cad_tri_v[cad_selected][j]]=TRUE;
  else
    return;

  for (i=0;i<cad_vertex_count;i++)
    if (moved[i]) {
      if (cad_selected_dim==0)
        cad_vertices[i].x+=amount;
      else if (cad_selected_dim==1)
        cad_vertices[i].y+=amount;
      else
        cad_vertices[i].z+=amount;
    }

  CadSyncTopologyToMesh;
  CadBounds;
  CadClampLayer;
  StrPrint(cad_status,"Moved %s %.1f MM on %c",
    CadSelectName,amount,'X'+cad_selected_dim);
}

U0 CadAdjustDimension(F64 amount)
{
  if (cad_type==HCAD_TYPE_IMPORTED) {
    CadStatus("Imported STL dimensions are read-only");
    return;
  }

  if (cad_type==HCAD_TYPE_BOX) {
    if (cad_selected_dim==0)
      cad_width=CadClampF(cad_width+amount,5,100);
    else if (cad_selected_dim==1)
      cad_depth=CadClampF(cad_depth+amount,5,100);
    else
      cad_height=CadClampF(cad_height+amount,5,100);
  } else {
    if (cad_selected_dim<2)
      cad_radius=CadClampF(cad_radius+amount/2.0,3,50);
    else
      cad_height=CadClampF(cad_height+amount,5,100);
  }
  CadRebuild;
}

U0 CadExportGCode()
{
  U8 *buf,*out;
  I64 layer,i,layers=CadLayerCount,lines=0;
  F64 z,e=0,dx,dy,d;

  buf=MAlloc(1024*1024);
  out=buf;
  StrPrint(out,"; HolyCAD V0.2 mesh slice\n");
  out+=StrLen(out);
  StrPrint(out,"; Educational perimeter output - review before printing\n");
  out+=StrLen(out);
  StrPrint(out,"G21\nG90\nM82\nG28\n");
  out+=StrLen(out);

  for (layer=0;layer<layers && out-buf<1000000;layer++) {
    z=cad_min_z+(layer+0.5)*cad_layer_height;
    CadSliceMesh(z);
    StrPrint(out,";LAYER:%d\n",layer);
    out+=StrLen(out);
    for (i=0;i<cad_seg_count && out-buf<1000000;i++) {
      StrPrint(out,"G0 X%7.3f Y%7.3f Z%6.3f F3600\n",
        cad_segs[i].x1+100.0,cad_segs[i].y1+100.0,z);
      out+=StrLen(out);
      dx=cad_segs[i].x2-cad_segs[i].x1;
      dy=cad_segs[i].y2-cad_segs[i].y1;
      d=Sqrt(dx*dx+dy*dy);
      e+=d*0.04;
      StrPrint(out,"G1 X%7.3f Y%7.3f E%8.4f F1200\n",
        cad_segs[i].x2+100.0,cad_segs[i].y2+100.0,e);
      out+=StrLen(out);
      lines++;
    }
  }
  StrPrint(out,"M104 S0\nM140 S0\nM84\n");
  out+=StrLen(out);
  FileWrite("B:/HolyCAD.GCODE",buf,out-buf);
  Free(buf);
  CadStatus("Exported B:/HolyCAD.GCODE (review before printing)");
}

U0 CadHandleClick(I64 x,I64 y)
{
  if (8<=x<98) {
    if (51<=y<72)
      CadSelectBox;
    else if (76<=y<97)
      CadSelectCylinder;
    else if (101<=y<122)
      CadLoadSTL("C:/HolyCube.STL");
    else if (146<=y<167)
      CadSelectMode(HCAD_SELECT_VERTEX);
    else if (171<=y<192)
      CadSelectMode(HCAD_SELECT_EDGE);
    else if (196<=y<217)
      CadSelectMode(HCAD_SELECT_FACE);
    else if (241<=y<262) {
      cad_mode=HCAD_MODE_MODEL;
      CadStatus("Model workspace");
    } else if (266<=y<287) {
      cad_mode=HCAD_MODE_SLICE;
      CadStatus("Mesh slice preview");
    } else if (291<=y<312)
      CadCycleView;
    else if (316<=y<337) {
      cad_show_gizmo=!cad_show_gizmo;
      CadStatus("Transform gizmo toggled");
    } else if (361<=y<382)
      CadExportGCode;
    else if (386<=y<407) {
      cad_show_infill=!cad_show_infill;
      CadStatus("Infill preview toggled");
    }
  }
}

U0 CadMouse()
{
  I64 x=ms.pos.x-Fs->pix_left-Fs->scroll_x;
  I64 y=ms.pos.y-Fs->pix_top-Fs->scroll_y;

  if (ms.lb && !cad_prev_lb) {
    if (cad_mode==HCAD_MODE_MODEL &&
        HCAD_VIEW_LEFT<=x<HCAD_VIEW_RIGHT &&
        HCAD_VIEW_TOP<=y<HCAD_VIEW_BOTTOM) {
      cad_dragging=TRUE;
      cad_drag_moved=FALSE;
      cad_drag_start_x=x;
      cad_drag_start_y=y;
      cad_drag_x=x;
      cad_drag_y=y;
    } else
      CadHandleClick(x,y);
  }

  if (ms.lb && cad_dragging) {
    if (Abs(x-cad_drag_start_x)>3 || Abs(y-cad_drag_start_y)>3)
      cad_drag_moved=TRUE;
    if (cad_drag_moved) {
      cad_yaw+=(x-cad_drag_x)*0.012;
      cad_pitch+=(y-cad_drag_y)*0.012;
      cad_pitch=CadClampF(cad_pitch,-1.45,1.45);
    }
    cad_drag_x=x;
    cad_drag_y=y;
  }

  if (!ms.lb && cad_prev_lb && cad_dragging) {
    if (!cad_drag_moved)
      CadPick(x,y);
    cad_dragging=FALSE;
  }
  cad_prev_lb=ms.lb;
}

U0 CadReadKeys()
{
  I64 ch,sc;
  while (ScanKey(&ch,&sc)) {
    switch (ch) {
      case 0:
        switch (sc.u8[0]) {
          case SC_CURSOR_LEFT:
            cad_yaw-=0.12;
            break;
          case SC_CURSOR_RIGHT:
            cad_yaw+=0.12;
            break;
          case SC_CURSOR_UP:
            cad_pitch=CadClampF(cad_pitch-0.10,-1.45,1.45);
            break;
          case SC_CURSOR_DOWN:
            cad_pitch=CadClampF(cad_pitch+0.10,-1.45,1.45);
            break;
        }
        break;
      case '1':
        CadSelectBox;
        break;
      case '2':
        CadSelectCylinder;
        break;
      case 'o':
      case 'O':
        CadLoadSTL("C:/HolyCube.STL");
        break;
      case 'v':
      case 'V':
        cad_mode=HCAD_MODE_MODEL;
        CadStatus("Model workspace");
        break;
      case 'l':
      case 'L':
        cad_mode=HCAD_MODE_SLICE;
        CadStatus("Mesh slice preview");
        break;
      case 'q':
      case 'Q':
        CadSelectMode(HCAD_SELECT_VERTEX);
        break;
      case 'e':
      case 'E':
        CadSelectMode(HCAD_SELECT_EDGE);
        break;
      case 'f':
      case 'F':
        CadSelectMode(HCAD_SELECT_FACE);
        break;
      case CH_CTRLI:
        cad_select_mode++;
        if (cad_select_mode>HCAD_SELECT_FACE)
          cad_select_mode=HCAD_SELECT_VERTEX;
        CadSelectMode(cad_select_mode);
        break;
      case 'a':
      case 'A':
        cad_yaw-=0.12;
        break;
      case 'd':
      case 'D':
        cad_yaw+=0.12;
        break;
      case 'w':
      case 'W':
        cad_pitch=CadClampF(cad_pitch-0.10,-1.45,1.45);
        break;
      case 's':
      case 'S':
        cad_pitch=CadClampF(cad_pitch+0.10,-1.45,1.45);
        break;
      case 'x':
      case 'X':
        cad_selected_dim=0;
        CadStatus("X transform axis selected");
        break;
      case 'y':
      case 'Y':
        cad_selected_dim=1;
        CadStatus("Y transform axis selected");
        break;
      case 'z':
      case 'Z':
        cad_selected_dim=2;
        CadStatus("Z transform axis selected");
        break;
      case ',':
        if (cad_mode==HCAD_MODE_MODEL && cad_selected>=0)
          CadMoveSelection(-1.0);
        else
          CadAdjustDimension(-1.0);
        break;
      case '.':
        if (cad_mode==HCAD_MODE_MODEL && cad_selected>=0)
          CadMoveSelection(1.0);
        else
          CadAdjustDimension(1.0);
        break;
      case '<':
        cad_layer--;
        CadClampLayer;
        CadStatus("Previous slice layer");
        break;
      case '>':
        cad_layer++;
        CadClampLayer;
        CadStatus("Next slice layer");
        break;
      case 'i':
      case 'I':
        cad_show_infill=!cad_show_infill;
        CadStatus("Infill preview toggled");
        break;
      case 'm':
      case 'M':
        CadCycleView;
        break;
      case 'g':
      case 'G':
        cad_show_gizmo=!cad_show_gizmo;
        CadStatus("Transform gizmo toggled");
        break;
      case 'p':
      case 'P':
        CadExportGCode;
        break;
      case 'r':
      case 'R':
        CadFitView;
        cad_yaw=-0.65;
        cad_pitch=0.58;
        CadStatus("View reset and fitted");
        break;
      case '+':
      case '=':
        cad_zoom*=1.12;
        break;
      case '-':
      case '_':
        cad_zoom/=1.12;
        break;
      case CH_ESC:
      case CH_SHIFT_ESC:
        cad_quit=TRUE;
        break;
    }
  }
}

Bool CadGeometryTest()
{
  cad_width=40;
  cad_depth=30;
  cad_height=20;
  CadBuildBox;
  if (cad_tri_count!=12)
    return FALSE;
  if (Abs((cad_max_x-cad_min_x)-40)>0.001 ||
      Abs((cad_max_y-cad_min_y)-30)>0.001 ||
      Abs((cad_max_z-cad_min_z)-20)>0.001)
    return FALSE;
  if (CadSliceMesh(10.0)!=8)
    return FALSE;
  CadBuildTopology;
  if (cad_vertex_count!=8 || cad_edge_count!=18)
    return FALSE;

  cad_radius=18;
  cad_height=30;
  cad_cylinder_sides=32;
  CadBuildCylinder;
  if (cad_tri_count!=128)
    return FALSE;
  if (CadSliceMesh(15.0)!=64)
    return FALSE;
  CadBuildTopology;
  if (cad_vertex_count!=66 || cad_edge_count!=192)
    return FALSE;
  return TRUE;
}

U0 HolyCAD()
{
  SettingsPush;
  AutoComplete;
  WinBorder;
  WinMax;
  DocClear;

  cad_quit=FALSE;
  cad_dragging=FALSE;
  cad_prev_lb=FALSE;
  cad_show_infill=TRUE;
  cad_show_gizmo=TRUE;
  cad_mode=HCAD_MODE_MODEL;
  cad_view_mode=HCAD_VIEW_SHADED;
  cad_select_mode=HCAD_SELECT_VERTEX;
  cad_selected=-1;
  cad_layer_height=0.20;
  cad_infill_spacing=4.0;
  cad_yaw=-0.65;
  cad_pitch=0.58;
  CadSelectBox;
  CadStatus("Ready - click vertex, drag orbit, M view, Q/E/F select");

  Fs->draw_it=&HolyCADDraw;
  try {
    while (!cad_quit) {
      CadReadKeys;
      CadMouse;
      if (cad_mode==HCAD_MODE_SLICE)
        CadSliceMesh(CadLayerZ);
      Refresh;
      Sleep(20);
    }
  } catch
    PutExcept;

  Fs->draw_it=NULL;
  DCFill;
  SettingsPop;
}

if (CadGeometryTest)
  HolyCAD;
else
  "HolyCAD geometry self-test FAILED.\n";
