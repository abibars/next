#include <re.h>
#include <baresip.h>
#include <studiolink.h>

static struct websock *ws = NULL;
static struct list wsl;
struct ws_conn {
	struct le le;
	struct websock_conn *c;
	enum ws_type type;
};


static void conn_destroy(void *arg)
{
	struct ws_conn *ws_conn = arg;
	mem_deref(ws_conn->c);
	list_unlink(&ws_conn->le);
}


static void close_handler(int err, void *arg)
{
	struct ws_conn *ws_conn = arg;
	(void)err;

	mem_deref(ws_conn);
}


int sl_ws_open(struct http_conn *conn, enum ws_type type,
	       const struct http_msg *msg, websock_recv_h *recvh)
{
	struct ws_conn *ws_conn;
	int err;

	ws_conn = mem_zalloc(sizeof(*ws_conn), conn_destroy);
	if (!ws_conn)
		return ENOMEM;

	err = websock_accept(&ws_conn->c, ws, conn, msg, 0, recvh,
			     close_handler, ws_conn);
	if (err)
		goto out;

	ws_conn->type = type;

	list_append(&wsl, &ws_conn->le, ws_conn);

out:
	if (err)
		mem_deref(ws_conn);
	return err;
}


void sl_ws_send_str(enum ws_type type, char *str)
{
	struct le *le;

	LIST_FOREACH(&wsl, le)
	{
		struct ws_conn *ws_conn = le->data;
		if (ws_conn->type != type)
			continue;
		websock_send(ws_conn->c, WEBSOCK_TEXT, "%s", str);
	}
}


int sl_ws_init(void)
{
	int err;

	list_init(&wsl);
	err = websock_alloc(&ws, NULL, NULL);

	return err;
}


int sl_ws_close(void)
{
	struct le *le = list_head(&wsl);
	struct ws_conn *ws_conn;

	while (le) {
		ws_conn = le->data;
		le	= le->next;
		mem_deref(ws_conn);
	}

	if (ws)
		ws = mem_deref(ws);

	return 0;
}