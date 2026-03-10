import "@typespec/http";
import "@typespec/rest";
import "@typespec/openapi3";
import "@typespec/versioning";

using Http;
using Rest;
using Versioning;

@service(#{ title: "DNS-API" })
@versioned(Versions)

namespace DnsApi {

  enum Versions {
    V1: "1.0"
  }

  model Comment {
    text: string;
  }

  model RecordData {
    data: string;
  }

  model RRSet {
    name: string;
    type: string;
    ttl: int32;
    changetype: string;
    record: RecordData[];
    comments: Comment[];
  }

  model Extension {
    name: string;
  }

  model Zone {
    @minLength(2)
    id: string;
    name: string;
    type: string;
    url: string;
    kind: string;
    rrsets: RRSet[];
    serial: int32;
    notified_serial: int32;
    edited_serial: int32;
    primaries: string[];
    dnssec: boolean;
    catalog: string;
    extensions: Extension[];
  }
}
