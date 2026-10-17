using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Data;
using Npgsql;
using NpgsqlTypes;
using TourismEcosystem.App.Domain;

namespace TourismEcosystem.App.Repositories;

public sealed class PaymentRepository : IPaymentRepository
{
    private readonly NpgsqlConnection _connection;
    private readonly Func<NpgsqlTransaction?> _transactionProvider;

    public PaymentRepository(NpgsqlConnection connection, Func<NpgsqlTransaction?> transactionProvider)
    {
        _connection = connection;
        _transactionProvider = transactionProvider;
    }

    public async Task<PaymentRegistrationResult> RegisterPaymentAsync(
        long actorUserId,
        long bookingId,
        decimal amount,
        string paymentMethod,
        string externalTxRef,
        CancellationToken ct = default)
    {
        const string sql = @"
            CALL tourism.sp_register_payment(
                @p_actor_user_id, @p_booking_id, @p_amount,
                @p_payment_method, @p_external_tx_ref,
                @o_payment_id, @o_new_booking_status
            );";

        await using var cmd = new NpgsqlCommand(sql, _connection, _transactionProvider());
        cmd.Parameters.AddWithValue("p_actor_user_id", NpgsqlDbType.Bigint, actorUserId);
        cmd.Parameters.AddWithValue("p_booking_id", NpgsqlDbType.Bigint, bookingId);
        cmd.Parameters.AddWithValue("p_amount", NpgsqlDbType.Numeric, amount);
        cmd.Parameters.AddWithValue("p_payment_method", NpgsqlDbType.Varchar, paymentMethod);
        cmd.Parameters.AddWithValue("p_external_tx_ref", NpgsqlDbType.Varchar, externalTxRef);

        var outPaymentId = new NpgsqlParameter("o_payment_id", NpgsqlDbType.Bigint)
        {
            Direction = ParameterDirection.InputOutput,
            Value = DBNull.Value
        };
        var outStatus = new NpgsqlParameter("o_new_booking_status", NpgsqlDbType.Varchar, 20)
        {
            Direction = ParameterDirection.InputOutput,
            Value = DBNull.Value
        };

        cmd.Parameters.Add(outPaymentId);
        cmd.Parameters.Add(outStatus);

        await cmd.ExecuteNonQueryAsync(ct);

        return new PaymentRegistrationResult(
            Convert.ToInt64(outPaymentId.Value),
            Convert.ToString(outStatus.Value) ?? string.Empty
        );
    }
}