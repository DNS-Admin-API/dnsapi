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
        changetype: changetype;
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

    model ServerParameters {
        @path
        @segment("servers")
        serverid: string;
    }

    model ZoneParameters {
        @path
        @segment("servers")
        serverid: string;

        @path
        @segment("zones")
        zoneid: string;
    }

    @route("/servers")
    namespace servers {
        @get op getZones(serverid: string): Zone[];
        @post op createZone(serverid: string, domainname: string): Zone;
        @route("/zones")
        namespace zones {
            @get op getZone(serverid: string, zoneid: string): Zone;
            @delete op deleteZone(serverid: string, zoneid: string): Zone;
            @patch op updateZone(serverid: string, zoneid: string, change: RRSet): Zone;
            @put op replaceZoneContent(serverid: string, zoneid: string, body: Zone): Zone;
            @route("/export")
            @get op getZoneAXFR(serverid: string, zoneid: string): string;
        }
    }
}
