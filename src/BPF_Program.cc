// See the file "COPYING" in the main distribution directory for copyright.

#include "config.h"

#include "util.h"
#include "BPF_Program.h"

#ifdef DONT_HAVE_LIBPCAP_PCAP_FREECODE
extern "C" {
#include "pcap-int.h"

int pcap_freecode(pcap_t* unused, struct bpf_program* program)
	{
	program->bf_len = 0;

	if ( program->bf_insns )
		{
		free((char*) program->bf_insns);	// copied from libpcap
		program->bf_insns = 0;
		}

	return 0;
	}

pcap_t* pcap_open_dead(int linktype, int snaplen)
	{
	pcap_t* p;

	p = (pcap_t*) malloc(sizeof(*p));
	if ( ! p )
		return 0;

	memset(p, 0, sizeof(*p));

	p->fd = -1;
	p->snapshot = snaplen;
	p->linktype = linktype;

	return p;
	}

int pcap_compile_nopcap(int snaplen_arg, int linktype_arg,
			struct bpf_program* program, char* buf,
			int optimize, bpf_u_int32 mask)
	{
	pcap_t* p;
	int ret;

	p = pcap_open_dead(linktype_arg, snaplen_arg);
	if ( ! p )
		return -1;

	ret = pcap_compile(p, program, buf, optimize, mask);
	pcap_close(p);

	return ret;
	}
}
#endif

BPF_Program::BPF_Program()
	{
	m_compiled = false;
	}

BPF_Program::~BPF_Program()
	{
	FreeCode();
	}

bool BPF_Program::Compile(pcap_t* pcap, const char* filter, uint32 netmask,
			  char* errbuf, unsigned int errbuf_len, bool optimize)
	{
	if ( ! pcap )
		return false;

	FreeCode();

	if ( pcap_compile(pcap, &m_program, (char *) filter, optimize, netmask) < 0 )
		{
		if ( errbuf )
			safe_snprintf(errbuf, errbuf_len,
				      "pcap_compile(%s): %s", filter,
				      pcap_geterr(pcap));

		return false;
		}

	m_compiled = true;

	return true;
	}

bool BPF_Program::Compile(int snaplen, int linktype, const char* filter,
				uint32 netmask, char* errbuf, bool optimize)
	{
	FreeCode();

#ifdef LIBPCAP_PCAP_COMPILE_NOPCAP_HAS_ERROR_PARAMETER
	char my_error[PCAP_ERRBUF_SIZE];

	int err = pcap_compile_nopcap(snaplen, linktype, &m_program,
				     (char *) filter, optimize, netmask, error);
	if ( err < 0 && errbuf )
		safe_strncpy(errbuf, my_errbuf, PCAP_ERRBUF_SIZE);
#else
	int err = pcap_compile_nopcap(snaplen, linktype, &m_program,
				     (char*) filter, optimize, netmask);
#endif
	if ( err == 0 )
		m_compiled = true;

	return err == 0;
	}

bpf_program* BPF_Program::GetProgram()
	{
	return m_compiled ? &m_program : 0;
	}

void BPF_Program::FreeCode()
	{
	if ( m_compiled )
		{
#ifdef DONT_HAVE_LIBPCAP_PCAP_FREECODE
		pcap_freecode(NULL, &m_program);
#else
		pcap_freecode(&m_program);
#endif
		m_compiled = false;
		}
	}
