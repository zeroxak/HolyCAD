#help_index "Graphics/CAD"

#define HCAD_MAX_TRIS       768
#define HCAD_MAX_VERTS      2304
#define HCAD_MAX_EDGES      2304
#define HCAD_EXPORT_BYTES (1024*1024)
#define HCAD_EXPORT_GUARD   2048

#define HCAD_TYPE_BOX         1
#define HCAD_TYPE_CYLINDER    2
#define HCAD_TYPE_IMPORTED    3

#define HCAD_MODE_OBJECT      1
#define HCAD_MODE_EDIT        2

#define HCAD_SELECT_VERTEX    1
#define HCAD_SELECT_EDGE      2
#define HCAD_SELECT_FACE      3

#define HCAD_VIEW_WIRE        1
#define HCAD_VIEW_SHADED      2

#define HCAD_VIEW_LEFT        0
#define HCAD_VIEW_RIGHT     640
#define HCAD_VIEW_TOP        28
#define HCAD_VIEW_BOTTOM    452

#define HCAD_TOOLS_LEFT       8
#define HCAD_TOOLS_TOP       40
#define HCAD_TOOLS_WIDTH    112
#define HCAD_TOOLS_BOTTOM   446

#define HCAD_PROPS_LEFT     480
#define HCAD_PROPS_TOP       40
#define HCAD_PROPS_WIDTH    152
#define HCAD_PROPS_BOTTOM   366

#define HCAD_EXPORT_LEFT    205
#define HCAD_EXPORT_TOP      44
#define HCAD_EXPORT_WIDTH   230
#define HCAD_EXPORT_BOTTOM  190

#define HCAD_PI 3.141592653589793

class HCadVec
{
  F64 x,y,z;
};

class HCadTri
{
  HCadVec p[3];
};

class HCadEdge
{
  I64 v[2];
};

HCadTri cad_tris[HCAD_MAX_TRIS];
HCadVec cad_vertices[HCAD_MAX_VERTS];
HCadEdge cad_edges[HCAD_MAX_EDGES];
I64 cad_tri_v[HCAD_MAX_TRIS][3];
I64 cad_face_order[HCAD_MAX_TRIS];
F64 cad_face_depth[HCAD_MAX_TRIS];
I64 cad_tri_count;
I64 cad_vertex_count,cad_edge_count;

I64 cad_type,cad_mode,cad_selected_dim,cad_view_mode;
I64 cad_select_mode,cad_selected;
I64 cad_selection_count;
I64 cad_cylinder_sides;
F64 cad_width,cad_depth,cad_height,cad_radius;
F64 cad_min_x,cad_min_y,cad_min_z;
F64 cad_max_x,cad_max_y,cad_max_z;
F64 cad_yaw,cad_pitch,cad_zoom,cad_view_off_x,cad_view_off_y;
F64 cad_pivot_x,cad_pivot_y,cad_pivot_z;
Bool cad_quit,cad_dragging,cad_drag_moved,cad_prev_lb;
Bool cad_show_gizmo,cad_object_selected;
Bool cad_tools_open,cad_props_open,cad_export_open;
Bool cad_multi_select,cad_component_selected[HCAD_MAX_VERTS];
I64 cad_drag_x,cad_drag_y,cad_drag_start_x,cad_drag_start_y;
U8 cad_name[32],cad_status[120];

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

U8 *CadModeName()
{
  if (cad_mode==HCAD_MODE_OBJECT)
    return "OBJECT";
  return "EDIT";
}

I64 CadSelectionLimit()
{
  if (cad_select_mode==HCAD_SELECT_VERTEX)
    return cad_vertex_count;
  if (cad_select_mode==HCAD_SELECT_EDGE)
    return cad_edge_count;
  return cad_tri_count;
}

U0 CadClearSelection()
{
  MemSet(cad_component_selected,0,sizeof(cad_component_selected));
  cad_selection_count=0;
  cad_selected=-1;
}

U0 CadResetSelection()
{
  CadClearSelection;
  cad_multi_select=FALSE;
}

Bool CadSelectComponent(I64 index)
{
  I64 i,limit=CadSelectionLimit;

  if (index<0 || index>=limit) {
    CadClearSelection;
    return FALSE;
  }

  if (!cad_multi_select)
    CadClearSelection;

  if (cad_multi_select && cad_component_selected[index]) {
    cad_component_selected[index]=FALSE;
    cad_selection_count--;
    if (cad_selected==index) {
      cad_selected=-1;
      for (i=limit-1;i>=0;i--)
        if (cad_component_selected[i]) {
          cad_selected=i;
          break;
        }
    }
    return FALSE;
  }

  if (!cad_component_selected[index]) {
    cad_component_selected[index]=TRUE;
    cad_selection_count++;
  }
  cad_selected=index;
  return TRUE;
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
  CadResetSelection;
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
  StrCpy(cad_name,"BOX");
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
  StrCpy(cad_name,"CYLINDER");
  CadStatus("Cylinder rebuilt from dimensions");
}

U0 CadFitView()
{
  F64 sx=cad_max_x-cad_min_x;
  F64 sy=cad_max_y-cad_min_y;
  F64 sz=cad_max_z-cad_min_z;
  F64 d=CadMaxF(sx,CadMaxF(sy,sz));

  cad_pivot_x=(cad_min_x+cad_max_x)/2.0;
  cad_pivot_y=(cad_min_y+cad_max_y)/2.0;
  cad_pivot_z=(cad_min_z+cad_max_z)/2.0;
  cad_view_off_x=0;
  cad_view_off_y=0;
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
  CadFitView;
}

Bool CadLoadSTL(U8 *filename)
{
  U8 *buf,*ptr,*vertex,*next;
  HCadTri *loaded;
  I64 loaded_count=0,vi=0;
  F64 x,y,z;

  if (!(buf=FileRead(filename))) {
    CadStatus("Could not open ASCII STL");
    return FALSE;
  }

  loaded=MAlloc(sizeof(HCadTri)*HCAD_MAX_TRIS);
  ptr=buf;
  while (vertex=StrMatch("vertex",ptr)) {
    next=StrScan(vertex,"vertex %f %f %f\n",&x,&y,&z);
    if (!next || next<=vertex)
      ptr=vertex+6;
    else {
      ptr=next;
      loaded[loaded_count].p[vi].x=x;
      loaded[loaded_count].p[vi].y=y;
      loaded[loaded_count].p[vi].z=z;
      if (++vi==3) {
        loaded_count++;
        vi=0;
        if (loaded_count>=HCAD_MAX_TRIS)
          break;
      }
    }
  }
  Free(buf);

  if (!loaded_count) {
    Free(loaded);
    CadStatus("No ASCII STL triangles found");
    return FALSE;
  }

  MemCpy(cad_tris,loaded,loaded_count*sizeof(HCadTri));
  Free(loaded);
  cad_tri_count=loaded_count;
  CadCenterMesh;
  CadBuildTopology;
  cad_type=HCAD_TYPE_IMPORTED;
  StrCpy(cad_name,"HOLYGEM.STL");
  CadFitView;
  cad_mode=HCAD_MODE_OBJECT;
  cad_object_selected=TRUE;
  cad_selected=-1;
  CadStatus("ASCII STL loaded and centered");
  return TRUE;
}

U0 CadProject(HCadVec *p,I64 *sx,I64 *sy,F64 *depth)
{
  F64 cy=Cos(cad_yaw),ss=Sin(cad_yaw);
  F64 cp=Cos(cad_pitch),sp=Sin(cad_pitch);
  F64 x=p->x-cad_pivot_x;
  F64 y=p->y-cad_pivot_y;
  F64 z=p->z-cad_pivot_z;
  F64 x1=x*cy-y*ss;
  F64 y1=x*ss+y*cy;
  F64 y2=y1*cp-z*sp;

  *depth=y1*sp+z*cp;
  *sx=(HCAD_VIEW_LEFT+HCAD_VIEW_RIGHT)/2+cad_view_off_x+
      x1*cad_zoom;
  *sy=(HCAD_VIEW_TOP+HCAD_VIEW_BOTTOM)/2+cad_view_off_y-
      y2*cad_zoom;
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
  dc->color=BLUE;
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
    return YELLOW;
  if (light>0.35)
    return LTRED;
  return LTBLUE;
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

U0 CadDrawWire(CDC *dc,I64 color=LTGRAY,I64 thick=1)
{
  I64 i;
  HCadTri *t;

  dc->thick=thick;
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
  Bool used[HCAD_MAX_VERTS];
  I64 i,j,a,b,count=0;

  if (cad_mode==HCAD_MODE_OBJECT) {
    if (!cad_object_selected)
      return FALSE;
    p->x=(cad_min_x+cad_max_x)/2.0;
    p->y=(cad_min_y+cad_max_y)/2.0;
    p->z=(cad_min_z+cad_max_z)/2.0;
    return TRUE;
  }

  if (!cad_selection_count)
    return FALSE;

  MemSet(used,0,sizeof(used));
  if (cad_select_mode==HCAD_SELECT_VERTEX) {
    for (i=0;i<cad_vertex_count;i++)
      if (cad_component_selected[i])
        used[i]=TRUE;
  } else if (cad_select_mode==HCAD_SELECT_EDGE) {
    for (i=0;i<cad_edge_count;i++)
      if (cad_component_selected[i]) {
        a=cad_edges[i].v[0];
        b=cad_edges[i].v[1];
        used[a]=used[b]=TRUE;
      }
  } else
    for (i=0;i<cad_tri_count;i++)
      if (cad_component_selected[i])
        for (j=0;j<3;j++)
          if (0<=cad_tri_v[i][j]<cad_vertex_count)
            used[cad_tri_v[i][j]]=TRUE;

  p->x=p->y=p->z=0;
  for (i=0;i<cad_vertex_count;i++)
    if (used[i]) {
      p->x+=cad_vertices[i].x;
      p->y+=cad_vertices[i].y;
      p->z+=cad_vertices[i].z;
      count++;
    }
  if (!count)
    return FALSE;
  p->x/=count;
  p->y/=count;
  p->z/=count;
  return TRUE;
}

U0 CadDrawSelectionCandidates(CDC *dc)
{
  I64 i,x,y,a,b;
  F64 z;
  HCadVec c;
  HCadTri *t;

  if (cad_mode!=HCAD_MODE_EDIT)
    return;

  if (cad_select_mode==HCAD_SELECT_FACE &&
      cad_view_mode==HCAD_VIEW_SHADED)
    for (i=0;i<cad_tri_count;i++)
      if (cad_component_selected[i])
        CadFillTri(dc,&cad_tris[i],GREEN);

  dc->thick=1;
  if (cad_select_mode==HCAD_SELECT_EDGE)
    dc->color=LTCYAN;
  else
    dc->color=LTBLUE;
  for (i=0;i<cad_edge_count;i++) {
    a=cad_edges[i].v[0];
    b=cad_edges[i].v[1];
    CadDrawProjectedLine(dc,&cad_vertices[a],&cad_vertices[b]);
  }

  if (cad_select_mode==HCAD_SELECT_VERTEX) {
    dc->color=LTCYAN;
    for (i=0;i<cad_vertex_count;i++) {
      CadProject(&cad_vertices[i],&x,&y,&z);
      GrRect(dc,x-1,y-1,3,3);
    }
  } else if (cad_select_mode==HCAD_SELECT_FACE) {
    dc->color=LTCYAN;
    for (i=0;i<cad_tri_count;i++) {
      t=&cad_tris[i];
      c.x=(t->p[0].x+t->p[1].x+t->p[2].x)/3.0;
      c.y=(t->p[0].y+t->p[1].y+t->p[2].y)/3.0;
      c.z=(t->p[0].z+t->p[1].z+t->p[2].z)/3.0;
      CadProject(&c,&x,&y,&z);
      GrRect(dc,x-1,y-1,3,3);
    }
  }
}

U0 CadDrawSelection(CDC *dc)
{
  I64 i,x,y,x2,y2,a,b,j;
  F64 z,z2;
  HCadTri *t;
  HCadVec *p1,*p2;

  if (cad_mode!=HCAD_MODE_EDIT || !cad_selection_count)
    return;

  if (cad_select_mode==HCAD_SELECT_VERTEX) {
    for (i=0;i<cad_vertex_count;i++)
      if (cad_component_selected[i]) {
        CadProject(&cad_vertices[i],&x,&y,&z);
        dc->color=YELLOW;
        GrRect(dc,x-4,y-4,9,9);
        if (i==cad_selected) {
          dc->color=WHITE;
          dc->thick=2;
          GrLine(dc,x-7,y,x+7,y);
          GrLine(dc,x,y-7,x,y+7);
        }
      }
  } else if (cad_select_mode==HCAD_SELECT_EDGE) {
    for (i=0;i<cad_edge_count;i++)
      if (cad_component_selected[i]) {
        a=cad_edges[i].v[0];
        b=cad_edges[i].v[1];
        p1=&cad_vertices[a];
        p2=&cad_vertices[b];
        dc->color=YELLOW;
        dc->thick=3;
        CadDrawProjectedLine(dc,p1,p2);
        CadProject(p1,&x,&y,&z);
        CadProject(p2,&x2,&y2,&z2);
        GrRect(dc,x-3,y-3,7,7);
        GrRect(dc,x2-3,y2-3,7,7);
      }
  } else
    for (i=0;i<cad_tri_count;i++)
      if (cad_component_selected[i]) {
        t=&cad_tris[i];
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

  if (cad_mode==HCAD_MODE_OBJECT) {
    if (cad_object_selected)
      CadDrawWire(dc,LTCYAN,2);
  } else {
    CadDrawSelectionCandidates(dc);
    CadDrawSelection(dc);
  }
  CadDrawGizmo(dc);
}

U0 CadButton(CDC *dc,I64 x,I64 y,I64 w,I64 h,U8 *label,Bool active=FALSE)
{
  if (active)
    dc->color=LTRED;
  else
    dc->color=BLUE;
  GrRect(dc,x,y,w,h);
  dc->color=WHITE;
  GrPrint(dc,x+(w-StrLen(label)*FONT_WIDTH)/2,
    y+(h-FONT_HEIGHT)/2,"%s",label);
}

U0 CadPanelBack(CDC *dc,I64 x,I64 y,I64 w,I64 h)
{
  dc->color=LTRED;
  GrRect(dc,x-2,y-2,w+4,h+4);
  dc->color=YELLOW;
  GrRect(dc,x,y,w,h);
}

U0 CadDrawHeader(CTask *task,CDC *dc)
{
  dc->color=RED;
  GrRect(dc,0,0,task->pix_width,28);
  dc->color=YELLOW;
  GrPrint(dc,8,6,"HOLYCAD");

  CadButton(dc,70,3,50,22,"FILE",cad_export_open);
  CadButton(dc,124,3,66,22,CadModeName,TRUE);
  if (cad_mode==HCAD_MODE_EDIT) {
    CadButton(dc,194,3,30,22,"1V",
      cad_select_mode==HCAD_SELECT_VERTEX);
    CadButton(dc,228,3,30,22,"2E",
      cad_select_mode==HCAD_SELECT_EDGE);
    CadButton(dc,262,3,30,22,"3F",
      cad_select_mode==HCAD_SELECT_FACE);
    CadButton(dc,296,3,70,22,"Q MULTI",cad_multi_select);
  }
  if (cad_view_mode==HCAD_VIEW_WIRE)
    CadButton(dc,370,3,72,22,"M WIRE",TRUE);
  else
    CadButton(dc,370,3,72,22,"M SOLID",TRUE);

  dc->color=YELLOW;
  GrPrint(dc,448,6,"V0.3");
  CadButton(dc,484,3,68,22,"T TOOLS",cad_tools_open);
  CadButton(dc,556,3,80,22,"N PANEL",cad_props_open);
}

U0 CadDrawTools(CDC *dc)
{
  if (!cad_tools_open)
    return;

  CadPanelBack(dc,HCAD_TOOLS_LEFT,HCAD_TOOLS_TOP,
    HCAD_TOOLS_WIDTH,HCAD_TOOLS_BOTTOM-HCAD_TOOLS_TOP);
  dc->color=BLACK;
  GrPrint(dc,16,48,"MESH TOOLS");

  dc->color=DKGRAY;
  GrPrint(dc,16,69,"MODE");
  CadButton(dc,15,84,98,21,"TAB OBJECT",
    cad_mode==HCAD_MODE_OBJECT);
  CadButton(dc,15,109,98,21,"TAB EDIT",
    cad_mode==HCAD_MODE_EDIT);

  dc->color=DKGRAY;
  GrPrint(dc,16,139,"SELECT");
  CadButton(dc,15,154,98,21,"1  VERTEX",
    cad_mode==HCAD_MODE_EDIT &&
    cad_select_mode==HCAD_SELECT_VERTEX);
  CadButton(dc,15,179,98,21,"2  EDGE",
    cad_mode==HCAD_MODE_EDIT &&
    cad_select_mode==HCAD_SELECT_EDGE);
  CadButton(dc,15,204,98,21,"3  FACE",
    cad_mode==HCAD_MODE_EDIT &&
    cad_select_mode==HCAD_SELECT_FACE);
  CadButton(dc,15,229,98,21,"Q  MULTI",
    cad_mode==HCAD_MODE_EDIT && cad_multi_select);

  dc->color=DKGRAY;
  GrPrint(dc,16,259,"ADD / OPEN");
  CadButton(dc,15,274,98,21,"B  BOX",cad_type==HCAD_TYPE_BOX);
  CadButton(dc,15,299,98,21,"C  CYLINDER",
    cad_type==HCAD_TYPE_CYLINDER);
  CadButton(dc,15,324,98,21,"O  IMPORT",
    cad_type==HCAD_TYPE_IMPORTED);

  dc->color=DKGRAY;
  GrPrint(dc,16,354,"VIEW / FILE");
  if (cad_view_mode==HCAD_VIEW_WIRE)
    CadButton(dc,15,369,98,21,"M  WIRE",TRUE);
  else
    CadButton(dc,15,369,98,21,"M  SHADED",TRUE);
  CadButton(dc,15,394,98,21,"G  GIZMO",cad_show_gizmo);
  CadButton(dc,15,419,98,21,"P  EXPORT",cad_export_open);
}

U0 CadDrawProps(CDC *dc)
{
  F64 sx=cad_max_x-cad_min_x;
  F64 sy=cad_max_y-cad_min_y;
  F64 sz=cad_max_z-cad_min_z;
  HCadVec p;

  if (!cad_props_open)
    return;

  CadPanelBack(dc,HCAD_PROPS_LEFT,HCAD_PROPS_TOP,
    HCAD_PROPS_WIDTH,HCAD_PROPS_BOTTOM-HCAD_PROPS_TOP);
  dc->color=BLACK;
  GrPrint(dc,488,48,"INSPECTOR");
  dc->color=DKGRAY;
  GrPrint(dc,488,66,"%s",cad_name);
  GrPrint(dc,488,87,"MODE     %s",CadModeName);
  GrPrint(dc,488,103,"%d VERT  %d EDGE",cad_vertex_count,cad_edge_count);
  GrPrint(dc,488,119,"%d FACE",cad_tri_count);

  dc->color=BLACK;
  GrPrint(dc,488,144,"ACTIVE");
  dc->color=DKGRAY;
  if (cad_mode==HCAD_MODE_OBJECT) {
    if (cad_object_selected)
      GrPrint(dc,488,161,"OBJECT SELECTED");
    else
      GrPrint(dc,488,161,"NONE");
  } else {
    if (cad_multi_select)
      GrPrint(dc,488,161,"%s  MULTI",CadSelectName);
    else
      GrPrint(dc,488,161,"%s  SINGLE",CadSelectName);
    GrPrint(dc,488,177,"SELECTED %d",cad_selection_count);
  }

  dc->color=BLACK;
  GrPrint(dc,488,203,"BOUNDS / MM");
  dc->color=DKGRAY;
  GrPrint(dc,488,220,"X %6.2f  Y %6.2f",sx,sy);
  GrPrint(dc,488,236,"Z %6.2f",sz);

  dc->color=BLACK;
  GrPrint(dc,488,262,"TRANSFORM");
  dc->color=DKGRAY;
  GrPrint(dc,488,279,"AXIS %c   , . MOVE",'X'+cad_selected_dim);
  if (CadSelectionCenter(&p)) {
    GrPrint(dc,488,295,"PX %7.2f",p.x);
    GrPrint(dc,488,311,"PY %7.2f",p.y);
    GrPrint(dc,488,327,"PZ %7.2f",p.z);
  } else
    GrPrint(dc,488,295,"NO SELECTION");

  dc->color=DKGRAY;
  GrPrint(dc,488,348,"N CLOSE");
}

U0 CadDrawExportMenu(CDC *dc)
{
  if (!cad_export_open)
    return;

  CadPanelBack(dc,HCAD_EXPORT_LEFT,HCAD_EXPORT_TOP,
    HCAD_EXPORT_WIDTH,HCAD_EXPORT_BOTTOM-HCAD_EXPORT_TOP);
  dc->color=BLACK;
  GrPrint(dc,217,54,"FILE > EXPORT MESH");
  dc->color=DKGRAY;
  GrPrint(dc,217,71,"SESSION B: WORK DISK");
  CadButton(dc,217,88,206,24,"1  ASCII STL");
  CadButton(dc,217,118,206,24,"2  WAVEFRONT OBJ");
  dc->color=DKGRAY;
  GrPrint(dc,217,151,"B:/HOLYCAD.STL / .OBJ");
  GrPrint(dc,217,169,"ESC OR OUTSIDE CLICK");
}

U0 CadDrawPanels(CTask *task,CDC *dc)
{
  CadDrawHeader(task,dc);
  CadDrawTools(dc);
  CadDrawProps(dc);
  CadDrawExportMenu(dc);

  dc->color=RED;
  GrRect(dc,0,task->pix_height-28,task->pix_width,28);
  dc->color=WHITE;
  GrPrint(dc,8,task->pix_height-20,"%.44s",cad_status);
  dc->color=YELLOW;
  if (cad_mode==HCAD_MODE_EDIT)
    GrPrint(dc,task->pix_width-FONT_WIDTH*31-8,task->pix_height-20,
      "EDIT | XRAY | %s | ORTHO",CadViewName);
  else
    GrPrint(dc,task->pix_width-FONT_WIDTH*27-8,task->pix_height-20,
      "OBJECT | %s | ORTHO",CadViewName);
}

U0 HolyCADDraw(CTask *task,CDC *dc)
{
  dc->color=BLACK;
  GrRect(dc,HCAD_VIEW_LEFT,HCAD_VIEW_TOP,
    HCAD_VIEW_RIGHT-HCAD_VIEW_LEFT,HCAD_VIEW_BOTTOM-HCAD_VIEW_TOP);

  CadDrawModelGrid(dc);
  CadDrawMesh(dc);

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
  cad_mode=HCAD_MODE_OBJECT;
  cad_object_selected=TRUE;
  cad_selected=-1;
}

U0 CadSelectCylinder()
{
  cad_type=HCAD_TYPE_CYLINDER;
  cad_radius=18;
  cad_height=30;
  cad_cylinder_sides=32;
  cad_selected_dim=0;
  CadRebuild;
  cad_mode=HCAD_MODE_OBJECT;
  cad_object_selected=TRUE;
  cad_selected=-1;
}

U0 CadSetMode(I64 mode)
{
  cad_mode=mode;
  cad_export_open=FALSE;
  CadResetSelection;
  if (mode==HCAD_MODE_OBJECT) {
    cad_object_selected=TRUE;
    CadStatus("Object: click mesh | X/Y/Z | , . move");
  } else {
    cad_object_selected=FALSE;
    CadStatus("Edit: Q multi | 1 vert | 2 edge | 3 face");
  }
}

U0 CadToggleMode()
{
  if (cad_mode==HCAD_MODE_OBJECT)
    CadSetMode(HCAD_MODE_EDIT);
  else
    CadSetMode(HCAD_MODE_OBJECT);
}

U0 CadSelectMode(I64 mode)
{
  cad_mode=HCAD_MODE_EDIT;
  cad_object_selected=FALSE;
  cad_select_mode=mode;
  CadResetSelection;
  StrPrint(cad_status,"Edit Mode %s - click select, drag orbit",
    CadSelectName);
}

U0 CadToggleMultiSelect()
{
  if (cad_mode!=HCAD_MODE_EDIT) {
    CadStatus("Q multi-select is available in Edit Mode");
    return;
  }

  cad_multi_select=!cad_multi_select;
  if (cad_multi_select)
    StrPrint(cad_status,"Multi ON: click toggles %s",
      CadSelectName);
  else
    StrPrint(cad_status,"Multi-select OFF - %d selected",
      cad_selection_count);
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

Bool CadTriPickDepth(F64 px,F64 py,
                     F64 x1,F64 y1,F64 z1,
                     F64 x2,F64 y2,F64 z2,
                     F64 x3,F64 y3,F64 z3,F64 *depth)
{
  F64 den=(y2-y3)*(x1-x3)+(x3-x2)*(y1-y3);
  F64 w1,w2,w3;

  if (Abs(den)<0.0001)
    return FALSE;
  w1=((y2-y3)*(px-x3)+(x3-x2)*(py-y3))/den;
  w2=((y3-y1)*(px-x3)+(x1-x3)*(py-y3))/den;
  w3=1.0-w1-w2;
  if (w1<-0.001 || w2<-0.001 || w3<-0.001)
    return FALSE;
  *depth=w1*z1+w2*z2+w3*z3;
  return TRUE;
}

U0 CadPick(I64 px,I64 py)
{
  I64 i,a,b,x1,y1,x2,y2,x3,y3,best=-1;
  F64 z1,z2,z3,zpick,d,best_d=1.0e30,best_z=-1.0e30;
  Bool selected_now;
  HCadTri *t;

  if (cad_mode==HCAD_MODE_OBJECT) {
    for (i=0;i<cad_tri_count;i++) {
      t=&cad_tris[i];
      CadProject(&t->p[0],&x1,&y1,&z1);
      CadProject(&t->p[1],&x2,&y2,&z2);
      CadProject(&t->p[2],&x3,&y3,&z3);
      if (CadTriPickDepth(px,py,x1,y1,z1,x2,y2,z2,x3,y3,z3,
          &zpick) && zpick>best_z) {
        best=i;
        best_z=zpick;
      }
    }
    cad_object_selected=best>=0;
    if (cad_object_selected)
      CadStatus("Object selected - X/Y/Z chooses move axis");
    else
      CadStatus("Object deselected");
    return;
  }

  if (cad_select_mode==HCAD_SELECT_VERTEX) {
    for (i=0;i<cad_vertex_count;i++) {
      CadProject(&cad_vertices[i],&x1,&y1,&z1);
      d=(px-x1)*(px-x1)+(py-y1)*(py-y1);
      if (d<=81 && (d<best_d || d==best_d && z1>best_z)) {
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
      if (d<=36 && (d<best_d ||
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
      if (CadTriPickDepth(px,py,x1,y1,z1,x2,y2,z2,x3,y3,z3,
          &zpick) && zpick>best_z) {
        best=i;
        best_z=zpick;
      }
    }
  }

  if (best<0) {
    CadClearSelection;
    CadStatus("Nothing under cursor - selection cleared");
  } else {
    selected_now=CadSelectComponent(best);
    if (selected_now)
      StrPrint(cad_status,"%s %d selected - %d total",
        CadSelectName,best+1,cad_selection_count);
    else
      StrPrint(cad_status,"%s %d deselected - %d remain",
        CadSelectName,best+1,cad_selection_count);
  }
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

  if (cad_mode!=HCAD_MODE_EDIT || !cad_selection_count) {
    CadStatus("Select a component before moving it");
    return;
  }

  MemSet(moved,0,sizeof(moved));
  if (cad_select_mode==HCAD_SELECT_VERTEX) {
    for (i=0;i<cad_vertex_count;i++)
      if (cad_component_selected[i])
        moved[i]=TRUE;
  } else if (cad_select_mode==HCAD_SELECT_EDGE) {
    for (i=0;i<cad_edge_count;i++)
      if (cad_component_selected[i]) {
        a=cad_edges[i].v[0];
        b=cad_edges[i].v[1];
        moved[a]=moved[b]=TRUE;
      }
  } else
    for (i=0;i<cad_tri_count;i++)
      if (cad_component_selected[i])
        for (j=0;j<3;j++)
          if (0<=cad_tri_v[i][j]<cad_vertex_count)
            moved[cad_tri_v[i][j]]=TRUE;

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
  StrPrint(cad_status,"Moved %d %s components %.1f MM on %c",
    cad_selection_count,CadSelectName,amount,'X'+cad_selected_dim);
}

U0 CadMoveObject(F64 amount)
{
  I64 i;
  F64 dx=0,dy=0,dz=0,cy,ss,cp,sp,x1,y1,y2;

  if (cad_mode!=HCAD_MODE_OBJECT || !cad_object_selected) {
    CadStatus("Select the object before moving it");
    return;
  }

  if (cad_selected_dim==0)
    dx=amount;
  else if (cad_selected_dim==1)
    dy=amount;
  else
    dz=amount;

  cy=Cos(cad_yaw);
  ss=Sin(cad_yaw);
  cp=Cos(cad_pitch);
  sp=Sin(cad_pitch);
  x1=dx*cy-dy*ss;
  y1=dx*ss+dy*cy;
  y2=y1*cp-dz*sp;
  cad_view_off_x+=x1*cad_zoom;
  cad_view_off_y-=y2*cad_zoom;
  cad_pivot_x+=dx;
  cad_pivot_y+=dy;
  cad_pivot_z+=dz;

  for (i=0;i<cad_vertex_count;i++) {
    cad_vertices[i].x+=dx;
    cad_vertices[i].y+=dy;
    cad_vertices[i].z+=dz;
  }
  CadSyncTopologyToMesh;
  CadBounds;
  StrPrint(cad_status,"Moved object %.1f MM on %c",
    amount,'X'+cad_selected_dim);
}

U0 CadMoveActive(F64 amount)
{
  if (cad_mode==HCAD_MODE_OBJECT)
    CadMoveObject(amount);
  else
    CadMoveSelection(amount);
}

Bool CadExportCoordOK(F64 v)
{
  return v==v && Abs(v)<=1000000.0;
}

Bool CadExportPointOK(HCadVec *p)
{
  return CadExportCoordOK(p->x) && CadExportCoordOK(p->y) &&
         CadExportCoordOK(p->z);
}

Bool CadExportMeshOK(Bool need_topology)
{
  I64 i,j,v;

  if (cad_tri_count<1 || cad_tri_count>HCAD_MAX_TRIS)
    return FALSE;
  for (i=0;i<cad_tri_count;i++)
    for (j=0;j<3;j++) {
      if (!CadExportPointOK(&cad_tris[i].p[j]))
        return FALSE;
      if (need_topology) {
        v=cad_tri_v[i][j];
        if (v<0 || v>=cad_vertex_count)
          return FALSE;
      }
    }
  if (need_topology)
    for (i=0;i<cad_vertex_count;i++)
      if (!CadExportPointOK(&cad_vertices[i]))
        return FALSE;
  return TRUE;
}

U0 CadFaceNormal(HCadTri *t,HCadVec *n)
{
  F64 ax=t->p[1].x-t->p[0].x;
  F64 ay=t->p[1].y-t->p[0].y;
  F64 az=t->p[1].z-t->p[0].z;
  F64 bx=t->p[2].x-t->p[0].x;
  F64 by=t->p[2].y-t->p[0].y;
  F64 bz=t->p[2].z-t->p[0].z;
  F64 len;

  n->x=ay*bz-az*by;
  n->y=az*bx-ax*bz;
  n->z=ax*by-ay*bx;
  len=Sqrt(n->x*n->x+n->y*n->y+n->z*n->z);
  if (len>0.000000001) {
    n->x/=len;
    n->y/=len;
    n->z/=len;
  } else
    n->x=n->y=n->z=0;
}

Bool CadVerifyExport(U8 *path,I64 expected)
{
  U8 *check;
  I64 size;

  if (!(check=FileRead(path,&size)))
    return FALSE;
  Free(check);
  return size==expected;
}

U0 CadExportSTL()
{
  U8 *buf,*out;
  I64 i,j,size,wrote;
  Bool overflow=FALSE;
  HCadTri *t;
  HCadVec n;

  CadSyncTopologyToMesh;
  if (!CadExportMeshOK(FALSE)) {
    CadStatus("STL export stopped - invalid mesh coordinates");
    return;
  }

  buf=MAlloc(HCAD_EXPORT_BYTES);
  out=buf;
  StrPrint(out,"solid HolyCAD\n");
  out+=StrLen(out);
  for (i=0;i<cad_tri_count;i++) {
    if (out-buf>HCAD_EXPORT_BYTES-HCAD_EXPORT_GUARD) {
      overflow=TRUE;
      break;
    }
    t=&cad_tris[i];
    CadFaceNormal(t,&n);
    StrPrint(out,
      "  facet normal %10.7f %10.7f %10.7f\n"
      "    outer loop\n"
      "      vertex %12.6f %12.6f %12.6f\n"
      "      vertex %12.6f %12.6f %12.6f\n"
      "      vertex %12.6f %12.6f %12.6f\n"
      "    endloop\n"
      "  endfacet\n",
      n.x,n.y,n.z,
      t->p[0].x,t->p[0].y,t->p[0].z,
      t->p[1].x,t->p[1].y,t->p[1].z,
      t->p[2].x,t->p[2].y,t->p[2].z);
    out+=StrLen(out);
  }
  if (!overflow) {
    StrPrint(out,"endsolid HolyCAD\n");
    out+=StrLen(out);
  }

  size=out-buf;
  if (overflow) {
    Free(buf);
    CadStatus("STL export stopped - 1 MB buffer limit");
    return;
  }
  wrote=FileWrite("B:/HOLYCAD.STL",buf,size);
  Free(buf);
  cad_export_open=FALSE;
  if (!wrote)
    CadStatus("STL export write failed");
  else if (CadVerifyExport("B:/HOLYCAD.STL",size))
    StrPrint(cad_status,"Exported B:/HOLYCAD.STL - %d bytes",size);
  else
    CadStatus("STL export write verification failed");
}

U0 CadExportOBJ()
{
  U8 *buf,*out;
  I64 i,size,wrote;
  Bool overflow=FALSE;
  HCadVec n;

  CadSyncTopologyToMesh;
  if (!CadExportMeshOK(TRUE)) {
    CadStatus("OBJ export stopped - invalid mesh topology");
    return;
  }

  buf=MAlloc(HCAD_EXPORT_BYTES);
  out=buf;
  StrPrint(out,"# HolyCAD V0.3 mesh export\no HolyCADMesh\n");
  out+=StrLen(out);
  for (i=0;i<cad_vertex_count;i++) {
    if (out-buf>HCAD_EXPORT_BYTES-HCAD_EXPORT_GUARD) {
      overflow=TRUE;
      break;
    }
    StrPrint(out,"v %12.6f %12.6f %12.6f\n",
      cad_vertices[i].x,cad_vertices[i].y,cad_vertices[i].z);
    out+=StrLen(out);
  }
  for (i=0;i<cad_tri_count && !overflow;i++) {
    if (out-buf>HCAD_EXPORT_BYTES-HCAD_EXPORT_GUARD) {
      overflow=TRUE;
      break;
    }
    CadFaceNormal(&cad_tris[i],&n);
    StrPrint(out,"vn %10.7f %10.7f %10.7f\n",n.x,n.y,n.z);
    out+=StrLen(out);
  }
  if (!overflow) {
    StrPrint(out,"s off\n");
    out+=StrLen(out);
  }
  for (i=0;i<cad_tri_count && !overflow;i++) {
    if (out-buf>HCAD_EXPORT_BYTES-HCAD_EXPORT_GUARD) {
      overflow=TRUE;
      break;
    }
    StrPrint(out,"f %d//%d %d//%d %d//%d\n",
      cad_tri_v[i][0]+1,i+1,cad_tri_v[i][1]+1,i+1,
      cad_tri_v[i][2]+1,i+1);
    out+=StrLen(out);
  }

  size=out-buf;
  if (overflow) {
    Free(buf);
    CadStatus("OBJ export stopped - 1 MB buffer limit");
    return;
  }
  wrote=FileWrite("B:/HOLYCAD.OBJ",buf,size);
  Free(buf);
  cad_export_open=FALSE;
  if (!wrote)
    CadStatus("OBJ export write failed");
  else if (CadVerifyExport("B:/HOLYCAD.OBJ",size))
    StrPrint(cad_status,"Exported B:/HOLYCAD.OBJ - %d bytes",size);
  else
    CadStatus("OBJ export write verification failed");
}

Bool CadPointInUI(I64 x,I64 y)
{
  if (y<28 || y>=HCAD_VIEW_BOTTOM)
    return TRUE;
  if (cad_export_open)
    return TRUE;
  if (cad_tools_open &&
      HCAD_TOOLS_LEFT-2<=x<HCAD_TOOLS_LEFT+HCAD_TOOLS_WIDTH+2 &&
      HCAD_TOOLS_TOP-2<=y<HCAD_TOOLS_BOTTOM+2)
    return TRUE;
  if (cad_props_open &&
      HCAD_PROPS_LEFT-2<=x<HCAD_PROPS_LEFT+HCAD_PROPS_WIDTH+2 &&
      HCAD_PROPS_TOP-2<=y<HCAD_PROPS_BOTTOM+2)
    return TRUE;
  return FALSE;
}

U0 CadHandleClick(I64 x,I64 y)
{
  if (cad_export_open) {
    if (HCAD_EXPORT_LEFT<=x<HCAD_EXPORT_LEFT+HCAD_EXPORT_WIDTH &&
        88<=y<112)
      CadExportSTL;
    else if (HCAD_EXPORT_LEFT<=x<HCAD_EXPORT_LEFT+HCAD_EXPORT_WIDTH &&
             118<=y<142)
      CadExportOBJ;
    else {
      cad_export_open=FALSE;
      CadStatus("Export menu closed");
    }
    return;
  }

  if (y<28) {
    if (70<=x<120)
      cad_export_open=TRUE;
    else if (124<=x<190)
      CadToggleMode;
    else if (cad_mode==HCAD_MODE_EDIT && 194<=x<224)
      CadSelectMode(HCAD_SELECT_VERTEX);
    else if (cad_mode==HCAD_MODE_EDIT && 228<=x<258)
      CadSelectMode(HCAD_SELECT_EDGE);
    else if (cad_mode==HCAD_MODE_EDIT && 262<=x<292)
      CadSelectMode(HCAD_SELECT_FACE);
    else if (cad_mode==HCAD_MODE_EDIT && 296<=x<366)
      CadToggleMultiSelect;
    else if (370<=x<442)
      CadCycleView;
    else if (484<=x<552)
      cad_tools_open=!cad_tools_open;
    else if (556<=x<636)
      cad_props_open=!cad_props_open;
    return;
  }

  if (cad_tools_open && HCAD_TOOLS_LEFT<=x<
      HCAD_TOOLS_LEFT+HCAD_TOOLS_WIDTH) {
    if (84<=y<105)
      CadSetMode(HCAD_MODE_OBJECT);
    else if (109<=y<130)
      CadSetMode(HCAD_MODE_EDIT);
    else if (154<=y<175)
      CadSelectMode(HCAD_SELECT_VERTEX);
    else if (179<=y<200)
      CadSelectMode(HCAD_SELECT_EDGE);
    else if (204<=y<225)
      CadSelectMode(HCAD_SELECT_FACE);
    else if (229<=y<250)
      CadToggleMultiSelect;
    else if (274<=y<295)
      CadSelectBox;
    else if (299<=y<320)
      CadSelectCylinder;
    else if (324<=y<345)
      CadLoadSTL("C:/HolyGem.STL");
    else if (369<=y<390)
      CadCycleView;
    else if (394<=y<415) {
      cad_show_gizmo=!cad_show_gizmo;
      CadStatus("Transform gizmo toggled");
    } else if (419<=y<440)
      cad_export_open=TRUE;
    return;
  }
}

U0 CadMouse()
{
  I64 x=ms.pos.x-Fs->pix_left-Fs->scroll_x;
  I64 y=ms.pos.y-Fs->pix_top-Fs->scroll_y;

  if (ms.lb && !cad_prev_lb) {
    if (CadPointInUI(x,y))
      CadHandleClick(x,y);
    else if (HCAD_VIEW_LEFT<=x<HCAD_VIEW_RIGHT &&
        HCAD_VIEW_TOP<=y<HCAD_VIEW_BOTTOM) {
      cad_dragging=TRUE;
      cad_drag_moved=FALSE;
      cad_drag_start_x=x;
      cad_drag_start_y=y;
      cad_drag_x=x;
      cad_drag_y=y;
    }
  }

  if (ms.lb && cad_dragging) {
    if ((x-cad_drag_start_x)*(x-cad_drag_start_x)+
        (y-cad_drag_start_y)*(y-cad_drag_start_y)>25)
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
      CadPick(cad_drag_start_x,cad_drag_start_y);
    cad_dragging=FALSE;
  }
  cad_prev_lb=ms.lb;
}

U0 CadReadKeys()
{
  I64 ch,sc;
  while (ScanKey(&ch,&sc)) {
    if (cad_export_open) {
      switch (ch) {
        case '1':
          CadExportSTL;
          break;
        case '2':
          CadExportOBJ;
          break;
        case CH_ESC:
        case CH_SHIFT_ESC:
        case 'p':
        case 'P':
          cad_export_open=FALSE;
          CadStatus("Export menu closed");
          break;
      }
    } else {
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
          CadSelectMode(HCAD_SELECT_VERTEX);
          break;
        case '2':
          CadSelectMode(HCAD_SELECT_EDGE);
          break;
        case '3':
          CadSelectMode(HCAD_SELECT_FACE);
          break;
        case CH_CTRLI:
          CadToggleMode;
          break;
        case 'q':
        case 'Q':
          CadToggleMultiSelect;
          break;
        case 'b':
        case 'B':
          CadSelectBox;
          break;
        case 'c':
        case 'C':
          CadSelectCylinder;
          break;
        case 'o':
        case 'O':
          CadLoadSTL("C:/HolyGem.STL");
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
          CadMoveActive(-1.0);
          break;
        case '.':
          CadMoveActive(1.0);
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
        case 't':
        case 'T':
          cad_tools_open=!cad_tools_open;
          CadStatus("Tools overlay toggled");
          break;
        case 'n':
        case 'N':
          cad_props_open=!cad_props_open;
          CadStatus("Inspector overlay toggled");
          break;
        case 'p':
        case 'P':
          cad_export_open=TRUE;
          CadStatus("Export menu - 1 STL, 2 OBJ, Esc cancel");
          break;
        case 'r':
        case 'R':
          CadFitView;
          cad_yaw=-0.65;
          cad_pitch=0.58;
          CadStatus("View framed around mesh");
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
}

Bool CadGeometryTest()
{
  F64 x0,x1;

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
  CadBuildTopology;
  if (cad_vertex_count!=8 || cad_edge_count!=18)
    return FALSE;

  cad_mode=HCAD_MODE_EDIT;
  cad_select_mode=HCAD_SELECT_VERTEX;
  cad_multi_select=TRUE;
  if (!CadSelectComponent(0) || !CadSelectComponent(1) ||
      cad_selection_count!=2)
    return FALSE;
  if (CadSelectComponent(0) || cad_selection_count!=1 ||
      cad_component_selected[0])
    return FALSE;
  if (!CadSelectComponent(0) || cad_selection_count!=2)
    return FALSE;
  x0=cad_vertices[0].x;
  x1=cad_vertices[1].x;
  cad_selected_dim=0;
  CadMoveSelection(1.0);
  if (Abs(cad_vertices[0].x-x0-1.0)>0.001 ||
      Abs(cad_vertices[1].x-x1-1.0)>0.001)
    return FALSE;

  CadResetSelection;
  if (cad_selection_count || cad_selected>=0 || cad_multi_select)
    return FALSE;
  cad_select_mode=HCAD_SELECT_EDGE;
  cad_multi_select=TRUE;
  if (!CadSelectComponent(0) || !CadSelectComponent(1) ||
      cad_selection_count!=2)
    return FALSE;
  CadResetSelection;
  cad_select_mode=HCAD_SELECT_FACE;
  cad_multi_select=TRUE;
  if (!CadSelectComponent(0) || !CadSelectComponent(1) ||
      cad_selection_count!=2)
    return FALSE;
  CadResetSelection;

  cad_radius=18;
  cad_height=30;
  cad_cylinder_sides=32;
  CadBuildCylinder;
  if (cad_tri_count!=128)
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
  cad_show_gizmo=TRUE;
  cad_object_selected=TRUE;
  cad_tools_open=TRUE;
  cad_props_open=FALSE;
  cad_export_open=FALSE;
  cad_multi_select=FALSE;
  cad_mode=HCAD_MODE_OBJECT;
  cad_view_mode=HCAD_VIEW_SHADED;
  cad_select_mode=HCAD_SELECT_VERTEX;
  cad_selected=-1;
  cad_yaw=-0.65;
  cad_pitch=0.58;
  CadSelectBox;
  CadStatus("Object: Tab edit | T/N panels | P export");

  Fs->draw_it=&HolyCADDraw;
  try {
    while (!cad_quit) {
      CadReadKeys;
      CadMouse;
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
