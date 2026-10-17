using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using TourismEcosystem.App.Repositories;
using System.Data;
using Npgsql;
using TourismEcosystem.App.Repositories;

namespace TourismEcosystem.App.UnitOfWork;

public interface IUnitOfWork : IAsyncDisposable
{
    ITourRepository Tours { get; }
    IBookingRepository Bookings { get; }
    IPaymentRepository Payments { get; }

    Task BeginTransactionAsync(CancellationToken ct = default);
    Task CommitAsync(CancellationToken ct = default);
    Task RollbackAsync(CancellationToken ct = default);
}