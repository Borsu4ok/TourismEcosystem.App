using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Data;
using Npgsql;
using TourismEcosystem.App.Repositories;

namespace TourismEcosystem.App.UnitOfWork;

public sealed class PostgresUnitOfWork : IUnitOfWork
{
    private readonly NpgsqlConnection _connection;
    private NpgsqlTransaction? _transaction;
    private bool _disposed;

    public ITourRepository Tours { get; }
    public IBookingRepository Bookings { get; }
    public IPaymentRepository Payments { get; }

    private PostgresUnitOfWork(NpgsqlConnection connection)
    {
        _connection = connection;
        Tours = new TourRepository(_connection, () => _transaction);
        Bookings = new BookingRepository(_connection, () => _transaction);
        Payments = new PaymentRepository(_connection, () => _transaction);
    }

    public static async Task<PostgresUnitOfWork> CreateAsync(string connectionString, CancellationToken ct = default)
    {
        var conn = new NpgsqlConnection(connectionString);
        await conn.OpenAsync(ct);
        return new PostgresUnitOfWork(conn);
    }

    public async Task BeginTransactionAsync(CancellationToken ct = default)
    {
        if (_transaction is not null)
        {
            throw new InvalidOperationException("A transaction is already active.");
        }
        _transaction = await _connection.BeginTransactionAsync(IsolationLevel.ReadCommitted, ct);
    }

    public async Task CommitAsync(CancellationToken ct = default)
    {
        if (_transaction is null)
        {
            throw new InvalidOperationException("No active transaction to commit.");
        }
        try
        {
            await _transaction.CommitAsync(ct);
        }
        finally
        {
            await _transaction.DisposeAsync();
            _transaction = null;
        }
    }

    public async Task RollbackAsync(CancellationToken ct = default)
    {
        if (_transaction is null)
        {
            return;
        }
        try
        {
            await _transaction.RollbackAsync(ct);
        }
        finally
        {
            await _transaction.DisposeAsync();
            _transaction = null;
        }
    }

    public async ValueTask DisposeAsync()
    {
        if (_disposed)
        {
            return;
        }
        if (_transaction is not null)
        {
            await _transaction.DisposeAsync();
        }
        await _connection.DisposeAsync();
        _disposed = true;
    }
}
