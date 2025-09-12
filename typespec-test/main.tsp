import "@typespec/http";
import "@typespec/rest";
import "@typespec/openapi3";
import "@typespec/compiler";
import "@typespec/versioning";

using TypeSpec.Http;
using TypeSpec.Rest;
using TypeSpec.OpenAPI;
using TypeSpec.Versioning;

@service(#{
  title: "Inventory Service",
})
@versioned(Versions)
@doc("Stores and manages hardware device inventory, location, and event data for NGSM.")
namespace InventoryService {
  enum Versions {
    @doc("Version 1.0.0")
    v1: "1.0.0",
  }

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

  union DeviceStatus {
    "active",    // Installed and operational
    "inactive",  // Installed but powered off or not operational
    "failed",    // A hardware failure has been detected
    "maintenance", // Undergoing maintenance
  }

  /** Controlled vocabulary for physical location types */
  union LocationType {
    "rack_unit", "chassis_bay", "node_slot", "drive_bay", "power_outlet", "cooling_port", "other"
  }

  /** Location occupancy status */
  union LocationStatus {
    "occupied", "empty"
  }

  /** Event types for device lifecycle tracking */
  union EventType {
    "com.openchami.inventory.device.installed",
    "com.openchami.inventory.device.removed",
    "com.openchami.inventory.device.detected",
    "com.openchami.inventory.device.updated",
    "com.openchami.inventory.device.failed",
  }

  // ============================================================================
  // Core Data Models
  // ============================================================================

  /** Properties for creating or updating a Device. */
  model DeviceProperties {
    @doc("User-defined name for the resource.")
    name: string;

    @doc("The network hostname (FQDN) used for access like ssh.")
    hostname?: string;

    @doc("Type of hardware component.")
    componentType: string;

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

    @doc("Flexible key-value properties for other, non-standard data.")
    properties?: Record<unknown>;
  }

  /** A full Device resource, including server-generated fields. */
  model Device extends DeviceProperties {
    @doc("Primary identifier for the resource, a UUID.")
    @key
    id: UUID;

    @doc("The ID of the parent device this component is installed in.")
    @visibility(Lifecycle.Read)
    parentDeviceId?: UUID;

    @doc("A list of IDs for all devices installed in this component.")
    @visibility(Lifecycle.Read)
    childrenDeviceIds?: UUID[];

    @doc("Time of resource creation.")
    createdAt: utcDateTime;

    @doc("Time of the last resource update.")
    updatedAt?: utcDateTime;

    @doc("Time of resource deletion (for soft deletes).")
    deletedAt?: utcDateTime;
  }

  /** Properties for creating or updating a Location. */
  model LocationProperties {
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
  }

  /** A full Location resource, including server-generated fields. */
  model Location extends LocationProperties {
    @doc("Primary identifier for the location (e.g., xname).")
    @key
    id: LocationId;

    @doc("A system-generated ID derived from location attributes in properties.")
    @visibility(Lifecycle.Read)
    derivedId?: string;

    @doc("A list of IDs for all child locations within this location.")
    @visibility(Lifecycle.Read)
    childrenLocationIds?: LocationId[];

    @doc("Time of resource creation.")
    createdAt: utcDateTime;

    @doc("Time of the last resource update.")
    updatedAt?: utcDateTime;

    @doc("Time of resource deletion (for soft deletes).")
    deletedAt?: utcDateTime;
  }

  /**
   * An event record that conforms to the CloudEvents v1.0 specification.
   */
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
    subject?: string; // e.g., The device UUID

    @doc("Timestamp of when the event occurred.")
    time: utcDateTime;

    @doc("The inventory-specific payload of the event.")
    data: EventData;
  }

  /**
   * The specific data payload for an inventory event.
   */
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

  model PaginationInfo {
    count: int32;
    total: int32;
    offset: int32;
  }

  // Model for pagination query parameters
  model PaginationParams {
    @query limit?: int32;
    @query offset?: int32;
  }

  // Placeholder models for filtering
  model DeviceFilters {}
  model LocationFilters {}

  @error
  model ErrorResponse {
    code: string;
    message: string;
  }

  /** A template for standard CRUD operations on a resource. */
  interface ResourceOperations<TResource, TCreateOrUpdate, TKey, TFilters> {
    @get
    list(...TFilters, ...PaginationParams): {
      @statusCode statusCode: 200;
      @body body: { items: TResource[], ...PaginationInfo };
    } | ErrorResponse;

    @post
    create(@body resource: TCreateOrUpdate): {
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
    update(@path id: TKey, @body resource: TCreateOrUpdate): {
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

  @route("/inventory/devices")
  interface DeviceOperations
    extends ResourceOperations<Device, DeviceProperties, UUID, DeviceFilters> {
    @route("/{id}/history")
    @get
    getHistory(@path id: UUID, ...PaginationParams): {
      @statusCode statusCode: 200;
      @body body: { items: Event[], ...PaginationInfo };
    } | ErrorResponse;
  }

  @route("/inventory/locations")
  interface LocationOperations
    extends ResourceOperations<
      Location,
      LocationProperties,
      LocationId,
      LocationFilters
    > {
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

  @route("/inventory/events")
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
}