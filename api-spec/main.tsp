import "@typespec/http";
import "@typespec/rest";
import "@typespec/openapi3";
import "@typespec/versioning";

using Http;
using Rest;
using Rest.Resource;
using Versioning;

@service(#{ title: "DNS-API" })
@versioned(Versions)

namespace DnsApi {

    enum Versions {
        V1: "1.0"
    }

    enum changetype {
        REPLACE: "replace",
        ADD: "add",
        UPDATE: "update",
        DELETE: "delete"
    }

    enum servertype {
        BIND9: "bind9",
        KNOT: "knot",
        NSD: "nsd",
        POWERDNS: "powerdns",
        WINDOWS: "windows"
    }

    model Server {
        id: string;
        type: servertype;
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
        record: RecordData[];
        comments: Comment[];
    }

    model RRSetChange extends RRSet {
        changetype: changetype;        
    }

    model Extension {
        name: string;
    }

    model Zone {
        @key
        @minLength(2)
        @visibility(Lifecycle.Read, Lifecycle.Create)
        id: string;
        @visibility(Lifecycle.Read, Lifecycle.Create)
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

    // not used
    model ServerParameters {
        @path
        @segment("servers")
        serverid: string;
    }

    // not used
    model ZoneParameters {
        @path
        @segment("servers")
        serverid: string;

        @path
        @segment("zones")
        zoneid: string;
    }

    @route("/servers/{serverid}")
    namespace servers {
        @get op getZones(serverid: string): Zone[];
        @route("/zones")
        namespace zones {
            @post op createZone(serverid: string, @body body: Create<Zone>): ResourceCreatedResponse<Zone>;
            @route("/{zoneid}")
            namespace zoneops {
                @get op getZone(serverid: string, zoneid: string): Zone;
                @route("/rrsets")
                @get op getZoneRRSets(serverid: string, zoneid: string): RRSet[];
                @delete op deleteZone(serverid: string, zoneid: string): Zone;
                @patch(#{ implicitOptionality: false }) op updateZone(serverid: string, zoneid: string, @body change: RRSetChange): Zone;
                @put op replaceZoneContent(serverid: string, zoneid: string, @body body: Update<Zone>): Zone;
                @route("/export")
                @get op getZoneAXFR(serverid: string, zoneid: string): string;
            }
        }
    }
}
