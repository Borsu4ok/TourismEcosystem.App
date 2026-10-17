using TourismEcosystem.App.Services;
using TourismEcosystem.App.UnitOfWork;

var connectionString = Environment.GetEnvironmentVariable("TOURISM_DB_CONN")
    ?? "Host=localhost;Port=5432;Database=\"Tourism Ecosystem\";Username=postgres;Password=Gatix!23;SearchPath=tourism,public";

Console.WriteLine("=== 1. Searching Active Mountain Tours ===");
await using (var uow = await PostgresUnitOfWork.CreateAsync(connectionString))
{
    var offers = await uow.Tours.SearchActiveToursAsync(tag: "mountains");
    foreach (var offer in offers)
    {
        Console.WriteLine($"Tour [{offer.TourCode}]: {offer.TourTitle} | Price: {offer.EffectivePrice} USD | Seats: {offer.AvailableSeats}");
    }
}

var bookingService = new TourismBookingService(connectionString);

Console.WriteLine("\n=== 2. Executing Atomic Booking + Payment Transaction ===");
var confirmedBooking = await bookingService.BookAndPayAtomicallyAsync(
    actorUserId: 4,
    touristUserId: 4,
    departureId: 1,
    participantsCount: 2,
    promoCode: "AUTUMN10",
    excursionId: 1,
    paymentMethod: "Card",
    externalTxRef: $"TX-NET-{Guid.NewGuid():N}"
);
Console.WriteLine($"Success! Booking #{confirmedBooking.BookingNumber} for {confirmedBooking.TouristName}");
Console.WriteLine($"Total: {confirmedBooking.TotalAmount} USD | Paid: {confirmedBooking.PaidAmount} USD | Status: {confirmedBooking.BookingStatus}");

Console.WriteLine("\n=== 3. Testing Transaction Rollback (Duplicate External Transaction Ref) ===");
try
{
    await bookingService.BookAndPayAtomicallyAsync(
        actorUserId: 5,
        touristUserId: 5,
        departureId: 1,
        participantsCount: 3,
        promoCode: null,
        excursionId: null,
        paymentMethod: "Card",
        externalTxRef: "TX-STRIPE-90001"
    );
}
catch (Exception ex)
{
    Console.WriteLine($"Transaction rolled back as expected: {ex.Message}");
}

Console.WriteLine("\n=== 4. Testing Soft Delete and Restore Workflow ===");
await using (var uow = await PostgresUnitOfWork.CreateAsync(connectionString))
{
    await uow.BeginTransactionAsync();
    await uow.Tours.SoftDeleteTourAsync(actorUserId: 1, tourId: 3);
    await uow.CommitAsync();
    Console.WriteLine("Tour ID=3 has been soft-deleted.");

    var deletedList = await uow.Tours.GetDeletedRecordsAsync();
    foreach (var rec in deletedList)
    {
        Console.WriteLine($"Deleted Record -> Entity: {rec.EntityType}, ID: {rec.RecordId}, Info: {rec.Identifier}, DeletedBy: {rec.DeletedByUserId}");
    }

    await uow.BeginTransactionAsync();
    await uow.Tours.RestoreRecordAsync(actorUserId: 1, entityName: "tours", recordId: 3);
    await uow.CommitAsync();
    Console.WriteLine("Tour ID=3 has been restored.");
}