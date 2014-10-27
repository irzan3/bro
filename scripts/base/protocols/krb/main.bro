##! Implements base functionality for KRB analysis. Generates the krb.log file.

module KRB;

@load ./consts

export {
	redef enum Log::ID += { LOG };

	type Info: record {
		## Timestamp for when the event happened.
		ts:     time    &log;
		## Unique ID for the connection.
		uid:    string  &log;
		## The connection's 4-tuple of endpoint addresses/ports.
		id:     conn_id &log;
		## Client
		client:	string &log &optional;
		## Service
		service:string &log;
		## Ticket valid from
		from:	time &log &optional;
		## Ticket valid till
		till:	time &log &optional;
		## Result
		result:	string &log &default="unknown";
		## Error code
		error_code: count &log &optional;
		## Error message
		error_msg: string &log &optional;
		## We've already logged this
		logged: bool &default=F;
	};

	## Event that can be handled to access the KRB record as it is sent on
	## to the loggin framework.
	global log_krb: event(rec: Info);
}

redef record connection += {
	krb: Info &optional;
};

const ports = { 88/udp };

event bro_init() &priority=5
	{
	Log::create_stream(KRB::LOG, [$columns=Info, $ev=log_krb]);
	Analyzer::register_for_ports(Analyzer::ANALYZER_KRB, ports);
	}

event krb_error(c: connection, msg: Error_Msg)
	{
	local info: Info;

	if ( c?$krb && c$krb$logged )
		return;
	
	if ( c?$krb )
		info = c$krb;
		
	if ( ! info?$ts )
		{
		info$ts  = network_time();
		info$uid = c$uid;
		info$id  = c$id;
		}

	if ( ! info?$client )
		if ( msg?$client_name || msg?$client_realm )
			info$client = fmt("%s%s", msg?$client_name ? msg$client_name + "/" : "",
		  			 	 	  		  msg?$client_realm ? msg$client_realm : "");

	info$service = msg$service_name;
	info$result = "failed";

	info$error_code = msg$error_code;
	
	if ( msg?$error_text )
		info$error_msg = msg$error_text;
	else
		{
		if ( msg$error_code in error_msg )
			info$error_msg = error_msg[msg$error_code];
		}
		
	Log::write(KRB::LOG, info);
	info$logged = T;

	c$krb = info;
	}

event krb_as_req(c: connection, msg: KDC_Request)
	{
	if ( c?$krb && c$krb$logged )
		return;
	
	local info: Info;
	info$ts  = network_time();
	info$uid = c$uid;
	info$id  = c$id;
	info$client = fmt("%s/%s", msg$client_name, msg$service_realm);
	info$service = msg$service_name;
	if ( msg?$from )
		info$from = msg$from;
	info$till = msg$till;
	
	c$krb = info;
	}

event krb_tgs_req(c: connection, msg: KDC_Request)
	{
	if ( c?$krb && c$krb$logged )
		return;

	local info: Info;
	info$ts  = network_time();
	info$uid = c$uid;
	info$id  = c$id;
	info$service = msg$service_name;
	if ( msg?$from )
		info$from = msg$from;
	info$till = msg$till;

	c$krb = info;
	}

event krb_as_rep(c: connection, msg: KDC_Reply)
	{
	local info: Info;

	if ( c?$krb && c$krb$logged )
		return;

	if ( c?$krb )
		info = c$krb;
		
	if ( ! info?$ts )
		{
		info$ts  = network_time();
		info$uid = c$uid;
		info$id  = c$id;
		}

	if ( ! info?$client )
		info$client = fmt("%s/%s", msg$client_name, msg$client_realm);

	info$service = msg$ticket$service_name;
	info$result = "success";
		
	Log::write(KRB::LOG, info);
	info$logged = T;

	c$krb = info;
	}

event krb_tgs_rep(c: connection, msg: KDC_Reply)
	{
	local info: Info;

	if ( c?$krb && c$krb$logged )
		return;

	if ( c?$krb )
		info = c$krb;
		
	if ( ! info?$ts )
		{
		info$ts  = network_time();
		info$uid = c$uid;
		info$id  = c$id;
		}

	if ( ! info?$client )
		info$client = fmt("%s/%s", msg$client_name, msg$client_realm);

	info$service = msg$ticket$service_name;
	info$result = "success";
		
	Log::write(KRB::LOG, info);
	info$logged = T;

	c$krb = info;
	}

event connection_state_remove(c: connection)
	{
	if ( c?$krb && ! c$krb$logged )
		Log::write(KRB::LOG, c$krb);
	}