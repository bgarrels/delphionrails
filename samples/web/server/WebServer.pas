unit WebServer;
interface
uses
  Windows, dorHTTPStub, dorSocketStub, Winsock, superobject, mypool,
  dorCairolib, dorCairo;

type
  THTTPServer = class(TSocketServer)
  protected
    function doOnCreateStub(Socket: longint; AAddress: TSockAddr): TSocketStub; override;
  end;

  THTTPConnexion = class(THTTPStub)
  private
    procedure PaitImg(const ctx: ICairoContext);
  protected
    function GetPassPhrase: AnsiString; override;
    procedure ProcessRequest; override;
  public
    type
      TBlog = record
        id: Integer;
        title: string;
        body: string;
      end;
    procedure ctrl_blog_index_get;
    procedure ctrl_blog_new_post(const title, body: string);
    procedure ctrl_blog_view_get(id: Integer);
    procedure ctrl_blog_edit_get(id: Integer);
    procedure ctrl_blog_edit_post(const data: TBlog);
    procedure ctrl_blog_delete_post(id: Integer);

    procedure ctrl_cairo_getimg_get(x, y: Integer);
    procedure view_cairo_getimg_png;
    procedure view_cairo_getimg_svg;
    procedure view_cairo_getimg_pdf;
    procedure view_cairo_getimg_ps;
  end;

implementation
uses SysUtils, dorDB, dorService;

const
  PASS_PHRASE: AnsiString = 'dc62rtd6fc14ss6df464c2s3s3rt324h14vh27d3fc321h2vfghv312';

{ THTTPConnexion }

procedure THTTPConnexion.ctrl_blog_delete_post(id: Integer);
begin
  with pool.GetConnection.newContext do
    Execute(newCommand('delete from blog where id = ?'), id);
  Redirect('blog', 'index');
end;

procedure THTTPConnexion.ctrl_blog_edit_get(id: Integer);
begin
  with pool.GetConnection.newContext do
    Context['data'] := Execute(newSelect('select * from blog where id = ?', true), id);
end;

procedure THTTPConnexion.ctrl_blog_edit_post(const data: TBlog);
begin
  with pool.GetConnection.newContext do
   Execute(newCommand('update blog set title = ?, body = ? where id = ?'),
     [data.title, data.body, data.id]);
  Context.S['info'] := 'updated';
end;

procedure THTTPConnexion.ctrl_blog_index_get;
begin
  with pool.GetConnection.newContext do
    Context['data'] := Execute(newSelect('select title, id from blog order by post_date'));
end;

procedure THTTPConnexion.ctrl_blog_new_post(const title, body: string);
begin
  with pool.GetConnection.newContext do
   Redirect(Execute(newFunction('insert into blog (title, body) values (?, ?) returning id'),
     [title, body]).Format('/blog/view/%id%'));
end;

procedure THTTPConnexion.ctrl_blog_view_get(id: Integer);
begin
  with pool.GetConnection.newContext do
    Context['data'] := Execute(newSelect('select * from blog where id = ?', true), id);
  if Context['data'] = nil then
    ErrorCode := 404;
  Compress := true;
end;

procedure THTTPConnexion.ctrl_cairo_getimg_get(x, y: Integer);
begin
  Context.I['x'] := x;
  Context.I['y'] := y;
end;

function THTTPConnexion.GetPassPhrase: AnsiString;
begin
  Result := PASS_PHRASE;
end;

procedure THTTPConnexion.PaitImg(const ctx: ICairoContext);
var
  pat, lin: ICairoPattern;
  i, j: integer;
begin
  ctx.SetSourceColor(aclWhite);
  ctx.Paint;

  pat := TCairoPattern.CreateRadial(0.25, 0.25, 0.1,  0.5, 0.5, 0.5);
  pat.AddColorStopRGB(0, 1.0, 0.8, 0.8);
  pat.AddColorStopRGB(1, 0.9, 0.0, 0.0);

  for i := 1 to 10 do
    for j := 1 to 10 do
      ctx.Rectangle(i/10.0 - 0.09, j/10.0 - 0.09, 0.08, 0.08);
  ctx.Source := pat;
  ctx.Fill;

  lin := TCairoPattern.CreateLinear(0.25, 0.35, 0.75, 0.65);
  lin.AddColorStopRGBA(0.00,  1, 1, 1, 0);
  lin.AddColorStopRGBA(0.25,  0, 1, 0, 0.5);
  lin.AddColorStopRGBA(0.50,  1, 1, 1, 0);
  lin.AddColorStopRGBA(0.75,  0, 0, 1, 0.5);
  lin.AddColorStopRGBA(1.00,  1, 1, 1, 0);

  ctx.Rectangle(0.0, 0.0, 1, 1);
  ctx.source := lin;
  ctx.Fill;

  ctx.SetSourceColor(aclBlack);
  ctx.SelectFontFace('Sans', CAIRO_FONT_SLANT_ITALIC, CAIRO_FONT_WEIGHT_BOLD);
  ctx.SetFontSize(0.3);
  ctx.MoveTo(0, 0.5);
  ctx.ShowText('Hello');
end;

procedure THTTPConnexion.ProcessRequest;
begin
  inherited;
  // automatic render context to json
  if (ErrorCode = 404) and (Params.AsObject.S['format'] = 'json') then
  begin
    ErrorCode := 200;
    Render(Context, false);
    Response.AsObject.S['Cache-Control'] := 'private, max-age=0';
  end;
end;

procedure THTTPConnexion.view_cairo_getimg_pdf;
var
  ctx: ICairoContext;
  surf: ICairoSurface;
begin
  surf := TPDFSurface.Create(Response.Content, Context.I['x'], Context.I['y']);
  ctx := TCairoContext.Create(surf);
  ctx.Scale(Context.I['x'], Context.I['y']);
  PaitImg(ctx);
end;

procedure THTTPConnexion.view_cairo_getimg_png;
var
  ctx: ICairoContext;
  surf: ICairoSurface;
begin
  surf := TImageSurface.Create(CAIRO_FORMAT_RGB24, Context.I['x'], Context.I['y']);
  ctx := TCairoContext.Create(surf);
  ctx.Scale(Context.I['x'], Context.I['y']);

  PaitImg(ctx);

  surf.WriteToPNGStream(Response.Content);
end;

procedure THTTPConnexion.view_cairo_getimg_ps;
var
  ctx: ICairoContext;
  surf: ICairoSurface;
begin
  surf := TPostScriptSurface.Create(Response.Content, Context.I['x'], Context.I['y']);
  ctx := TCairoContext.Create(surf);
  ctx.Scale(Context.I['x'], Context.I['y']);
  PaitImg(ctx);
end;

procedure THTTPConnexion.view_cairo_getimg_svg;
var
  ctx: ICairoContext;
  surf: ICairoSurface;
begin
  surf := TSVGSurface.Create(Response.Content, Context.I['x'], Context.I['y']);
  ctx := TCairoContext.Create(surf);
  ctx.Scale(Context.I['x'], Context.I['y']);
  PaitImg(ctx);
end;

{ THTTPServer }

function THTTPServer.doOnCreateStub(Socket: longint;
  AAddress: TSockAddr): TSocketStub;
begin
  Result := THTTPConnexion.CreateStub(Self, Socket, AAddress);
end;

initialization
  Application.CreateServer(THTTPServer, 81);

end.


