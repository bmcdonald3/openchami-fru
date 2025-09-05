import "@typespec/http";
import "@typespec/rest";
import "@typespec/openapi3";

using TypeSpec.Http;
using TypeSpec.Rest;
using TypeSpec.OpenAPI;

@service({
  title: "Inventory Service",
  version: "1.0.0",
})
@doc("Stores and manages hardware device inventory, location, and event data for NGSM.")
namespace InventoryService;

// ============================================================================
// Custom Scalar Types
// ============================================================================

@pattern("^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$")
scalar UUID extends string;

@pattern("^[a-zA-Z0-9_.-]+$")
scalar LocationId extends string;

// ============================================================================
// Custom Enum Types
// ============================================================================

union ComponentType { "Node", "Processor", "Memory", "Drive", "NetworkAdapter", "PowerSupply", "Fan", "Chassis", "Enclosure", "Switch", "Router", "PDU", "Outlet", "Cable", "Riser", "GPU", "BMC", "Rack", "Cabinet", "Other" }
union DeviceStatus { "active", "inactive", "failed", "maintenance" }
union LocationType { "rack_unit", "chassis_bay", "node_slot", "drive_bay", "power_outlet", "cooling_port", "other" }
union LocationStatus { "occupied", "empty" }
union EventType { "com.openchami.inventory.device.installed", "com.openchami.inventory.device.removed", "com.openchami.inventory.device.detected", "com.openchami.inventory.device.updated", "com.openchami.inventory.device.failed" }

// ============================================================================
// Core Data Models
// ============================================================================

model Device {
  @doc("Primary identifier for the resource, a UUID.")
  @key
  id: UUID;

  @doc("User-defined name for the resource.")
  name: string;

  @doc("The network hostname (FQDN) used for access like ssh.")
  hostname?: string;

  @doc("Type of hardware component.")
  componentType: ComponentType; // Changed from string

  @doc("Hardware manufacturer.")
  manufacturer: string;

  @doc("Manufacturer part number.")
  partNumber: string;

  @doc("Manufacturer serial number.")
  serialNumber: string;
  
  @doc("Current location where device is installed.")
  currentLocationId?: LocationId;

  @doc("Current status of the device.")
  status: DeviceStatus;
  
  @doc("Flexible key-value properties.")
  properties?: Record<unknown>;

  @doc("The ID of the parent device this component is installed in.")
  @visibility(read) // Corrected syntax
  parentDeviceId?: UUID;

  @doc("A list of IDs for all devices installed in this component.")
  @visibility(read) // Corrected syntax
  childrenDeviceIds?: UUID[];

  @doc("Time of resource creation.")
  createdAt: utcDateTime;

  @doc("Time of the last resource update.")
  updatedAt?: utcDateTime;

  @doc("Time of resource deletion (for soft deletes).")
  deletedAt?: utcDateTime;
}

model Location {
  @doc("Primary identifier for the location (e.g., xname).")
  @key
  id: LocationId;

  @doc("User-defined name for the location.")
  name: string;

  @doc("Type of location.")
  locationType: LocationType;

  @doc("Parent location identifier for hierarchy.")
  parentLocationId?: LocationId;

  @doc("ID of the device currently installed at this location.")
  currentDeviceId?: UUID;

  @doc("Current status of the location.")
  status: LocationStatus;

  @doc("Location-specific properties.")
  properties?: Record<unknown>;

  @doc("A list of IDs for all child locations within this location.")
  @visibility(read) // Corrected syntax
  childrenLocationIds?: LocationId[];

  @doc("Time of resource creation.")
  createdAt: utcDateTime;

  @doc("Time of the last resource update.")
  updatedAt?: utcDateTime;

  @doc("Time of resource deletion (for soft deletes).")
  deletedAt?: utcDateTime;
}

model Event {
  @doc("Unique identifier for the event.")
  @key
  id: UUID;

  @doc("Identifies the context in which an event happened. (e.g., /inventory/v1/api)")
  source: string;

  @doc("The version of the CloudEvents specification which this event uses.")
  specversion: "1.0";

  @doc("Describes the type of event related to the originating occurrence.")
  type: EventType;

  @doc("Content type of the data value. Defaults to application/json.")
  datacontenttype?: "application/json";

  @doc("Identifies the subject of the event in the context of the event producer.")
  subject?: string; 

  @doc("Timestamp of when the event occurred.")
  time: utcDateTime;

  @doc("The inventory-specific payload of the event.")
  data: EventData;
}

model EventData {
  @doc("The device involved in the event.")
  deviceId?: UUID;

  @doc("The location involved in the event.")
  locationId?: LocationId;

  @doc("The user, service, or actor that initiated the event.")
  actor?: string;

  @doc("A freeform text comment describing the reason for the event.")
  comment?: string;

  @doc("The duration of the event in seconds.")
  duration?: int32;

  @doc("For update events, this can contain the state of the object before the change.")
  stateBefore?: Record<unknown>;
  
  @doc("For update events, this can contain the state of the object after the change.")
  stateAfter?: Record<unknown>;
}

// ============================================================================
// Supporting Models
// ============================================================================

// Added missing filter and pagination models
model DeviceFilters {
  @query componentType?: ComponentType;
  @query manufacturer?: string;
  @query partNumber?: string;
  @query serialNumber?: string;
  @query status?: DeviceStatus;
  @query location?: LocationId;
}

model LocationFilters {
  @query locationType?: LocationType;
  @query parentLocationId?: LocationId;
  @query status?: LocationStatus;
  @query occupied?: boolean;
}

model PaginationParams {
  @query limit?: int32 = 50;
  @query offset?: int32 = 0;
}

model PaginationInfo {
  count: int32;
  total: int32;
  offset: int32;
}

@error
model ErrorResponse {
  code: string;
  message: string;
}

// ============================================================================
// Generic Operations Template
// ============================================================================

interface ResourceOperations<TResource, TKey, TFilters> {
  @get
  list(...TFilters, ...PaginationParams): {
    @statusCode statusCode: 200;
    @body body: { items: TResource[], ...PaginationInfo };
  } | ErrorResponse;

  @post
  create(@body resource: Omit<TResource, "id" | "createdAt" | "updatedAt" | "deletedAt">): {
    @statusCode statusCode: 201;
    @body body: TResource;
  } | ErrorResponse;

  @route("/{id}")
  @get
  get(@path id: TKey): {
    @statusCode statusCode: 200;
    @body body: TResource;
  } | ErrorResponse;

  @route("/{id}")
  @put
  update(@path id: TKey, @body resource: Omit<TResource, "id" | "createdAt" | "updatedAt" | "deletedAt">): {
    @statusCode statusCode: 200;
    @body body: TResource;
  } | ErrorResponse;

  @route("/{id}")
  @delete
  delete(@path id: TKey): { @statusCode statusCode: 204 } | ErrorResponse;
  
  @route("/by-name/{name}")
  @get
  getByName(@path name: string): {
    @statusCode statusCode: 200;
    @body body: TResource;
  } | ErrorResponse;
}

// ============================================================================
// API Operations
// ============================================================================

@route("/inventory/v1/devices")
interface DeviceOperations extends ResourceOperations<Device, UUID, DeviceFilters> {
  @route("/{id}/history")
  @get
  getHistory(@path id: UUID, ...PaginationParams): {
    @statusCode statusCode: 200;
    @body body: { items: Event[], ...PaginationInfo };
  } | ErrorResponse;
}

@route("/inventory/v1/locations")
interface LocationOperations extends ResourceOperations<Location, LocationId, LocationFilters> {
  @route("/{id}/history")
  @get
  getHistory(@path id: LocationId, ...PaginationParams): {
    @statusCode statusCode: 200;
    @body body: { items: Event[], ...PaginationInfo };
  } | ErrorResponse;
  
  @doc("Get the device at a location.")
  @route("/{id}/device")
  @get
  getDevice(@path id: LocationId): {
    @statusCode statusCode: 200;
    @body body: Device;
  } | ErrorResponse;

  @doc("Install a device at a location.")
  @route("/{id}/device")
  @put
  installDevice(@path id: LocationId, @body body: { deviceId: UUID }): {
    @statusCode statusCode: 200;
    @body body: { location: Location, event: Event };
  } | ErrorResponse;

  @doc("Remove a device from a location.")
  @route("/{id}/device")
  @delete
  removeDevice(@path id: LocationId): {
    @statusCode statusCode: 200;
    @body body: { location: Location, event: Event };
  } | ErrorResponse;
}

@route("/inventory/v1/events")
interface EventOperations {
  @get
  list(
    @query filter?: string,
    @query limit?: int32,
    @query offset?: int32
  ): {
    @statusCode statusCode: 200;
    @body body: { items: Event[], ...PaginationInfo };
  } | ErrorResponse;

  @route("/{id}")
  @get
  get(@path id: UUID): {
    @statusCode statusCode: 200;
    @body body: Event;
  } | ErrorResponse;
}
